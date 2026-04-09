import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { format } from 'date-fns'
import { MapPin, RefreshCw, Building2 } from 'lucide-react'
import Loading from '../components/Loading'
import EmptyState from '../components/EmptyState'
import { showSuccess, showError } from '../utils/toast'

const Workspaces = () => {
  const [workspaces, setWorkspaces] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchWorkspaces()
  }, [])

  const fetchWorkspaces = async () => {
    try {
      const { data, error } = await supabase
        .from('workspaces')
        .select('*')
        .order('created_at', { ascending: false })

      if (error) throw error
      setWorkspaces(data || [])
    } catch (error) {
      console.error('Error fetching workspaces:', error)
      showError('Failed to load workspaces: ' + error.message)
    } finally {
      setLoading(false)
    }
  }

  const handleToggleAvailability = async (workspaceId, currentStatus, workspaceName) => {
    try {
      const { error } = await supabase
        .from('workspaces')
        .update({ is_available: !currentStatus })
        .eq('id', workspaceId)

      if (error) throw error
      
      showSuccess(`Workspace "${workspaceName}" ${!currentStatus ? 'enabled' : 'disabled'} successfully`)
      fetchWorkspaces()
    } catch (error) {
      console.error('Error updating workspace:', error)
      showError('Error updating workspace: ' + error.message)
    }
  }

  if (loading) {
    return <Loading message="Loading workspaces..." />
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
            Workspaces
          </h1>
          <p style={{ 
            color: '#64748b', 
            fontSize: '16px',
            fontWeight: '500'
          }}>
            Manage all coworking spaces in the system
          </p>
        </div>
        <button
          onClick={fetchWorkspaces}
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

      {workspaces.length === 0 ? (
        <EmptyState
          icon={Building2}
          title="No workspaces found"
          message="Workspaces will appear here once owners create them"
        />
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          {workspaces.map((workspace) => (
            <div
              key={workspace.id}
              style={{
                backgroundColor: 'white',
                padding: '24px',
                borderRadius: '12px',
                boxShadow: '0 2px 8px rgba(0, 0, 0, 0.08)',
                border: `1px solid ${workspace.is_available ? '#e2e8f0' : '#fee2e2'}`,
                borderLeft: `4px solid ${workspace.is_available ? '#10b981' : '#ef4444'}`,
                transition: 'transform 0.2s, box-shadow 0.2s'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.transform = 'translateY(-2px)'
                e.currentTarget.style.boxShadow = '0 4px 12px rgba(0, 0, 0, 0.12)'
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.transform = 'translateY(0)'
                e.currentTarget.style.boxShadow = '0 2px 8px rgba(0, 0, 0, 0.08)'
              }}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', gap: '20px' }}>
                <div style={{ flex: 1 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '12px' }}>
                    <h3 style={{ 
                      fontSize: '20px', 
                      fontWeight: '600', 
                      color: '#1e293b' 
                    }}>
                      {workspace.name}
                    </h3>
                    <span style={{
                      padding: '4px 10px',
                      borderRadius: '6px',
                      fontSize: '11px',
                      fontWeight: '600',
                      backgroundColor: workspace.is_available ? '#d1fae5' : '#fee2e2',
                      color: workspace.is_available ? '#065f46' : '#991b1b'
                    }}>
                      {workspace.is_available ? '✓ Available' : '✗ Disabled'}
                    </span>
                  </div>
                  
                  <p style={{ 
                    color: '#64748b', 
                    marginBottom: '16px',
                    fontSize: '14px',
                    lineHeight: '1.6'
                  }}>
                    {workspace.description}
                  </p>
                  
                  <div style={{ 
                    display: 'flex', 
                    flexDirection: 'column', 
                    gap: '10px', 
                    marginBottom: '16px' 
                  }}>
                    <div style={{ 
                      display: 'flex', 
                      alignItems: 'center', 
                      gap: '10px', 
                      color: '#64748b',
                      fontSize: '14px'
                    }}>
                      <MapPin size={18} color="#94a3b8" />
                      <span>{workspace.address}, {workspace.city}</span>
                    </div>
                    <div style={{ 
                      display: 'flex', 
                      alignItems: 'center', 
                      gap: '10px', 
                      color: '#64748b',
                      fontSize: '14px'
                    }}>
                      <DollarSign size={18} color="#94a3b8" />
                      <span style={{ fontWeight: '600', color: '#1e293b' }}>
                        PKR {workspace.price_per_day}/day
                        {workspace.price_per_month && ` • PKR ${workspace.price_per_month}/month`}
                      </span>
                    </div>
                    {workspace.capacity && (
                      <div style={{ 
                        color: '#64748b',
                        fontSize: '14px',
                        marginLeft: '28px'
                      }}>
                        Capacity: {workspace.capacity} seats
                      </div>
                    )}
                  </div>

                  <div style={{ 
                    fontSize: '12px', 
                    color: '#94a3b8',
                    paddingTop: '12px',
                    borderTop: '1px solid #f1f5f9'
                  }}>
                    Created: {format(new Date(workspace.created_at), 'MMM dd, yyyy')}
                  </div>
                </div>

                <div style={{ marginLeft: '16px', flexShrink: 0 }}>
                  <button
                    onClick={() => handleToggleAvailability(workspace.id, workspace.is_available, workspace.name)}
                    style={{
                      padding: '10px 20px',
                      backgroundColor: workspace.is_available ? '#fee2e2' : '#d1fae5',
                      color: workspace.is_available ? '#dc2626' : '#059669',
                      border: 'none',
                      borderRadius: '8px',
                      cursor: 'pointer',
                      fontSize: '14px',
                      fontWeight: '600',
                      transition: 'all 0.2s',
                      whiteSpace: 'nowrap'
                    }}
                    onMouseEnter={(e) => {
                      e.target.style.transform = 'scale(1.05)'
                      e.target.style.boxShadow = '0 2px 4px rgba(0, 0, 0, 0.1)'
                    }}
                    onMouseLeave={(e) => {
                      e.target.style.transform = 'scale(1)'
                      e.target.style.boxShadow = 'none'
                    }}
                  >
                    {workspace.is_available ? 'Disable' : 'Enable'}
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

export default Workspaces

