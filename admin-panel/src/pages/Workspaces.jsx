import { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { format } from 'date-fns'
import { MapPin, RefreshCw, Building2, Banknote, FileText, ExternalLink } from 'lucide-react'
import Loading from '../components/Loading'
import EmptyState from '../components/EmptyState'
import { showSuccess, showError } from '../utils/toast'

const FILTERS = [
  { id: 'all', label: 'All' },
  { id: 'listed', label: 'Listed' },
  { id: 'pending', label: 'Pending' },
  { id: 'rejected', label: 'Rejected' },
]

function approvalMeta(ws) {
  if (ws.workspace_approved === null) {
    return { label: 'Pending Review', bg: '#fef3c7', color: '#92400e', border: '#fbbf24' }
  }
  if (ws.workspace_approved === false) {
    return { label: 'Rejected', bg: '#fee2e2', color: '#991b1b', border: '#ef4444' }
  }
  if (ws.is_available) {
    return { label: 'Listed', bg: '#d1fae5', color: '#065f46', border: '#10b981' }
  }
  return { label: 'Disabled', bg: '#f1f5f9', color: '#475569', border: '#94a3b8' }
}

const Workspaces = () => {
  const [workspaces, setWorkspaces] = useState([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('all')

  useEffect(() => {
    fetchWorkspaces()
  }, [])

  const fetchWorkspaces = async () => {
    try {
      setLoading(true)
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

  const handleToggleAvailability = async (workspace) => {
    if (workspace.workspace_approved !== true) {
      showError('Only approved workspaces can be enabled/disabled. Review in Workspace Requests first.')
      return
    }
    try {
      const { error } = await supabase
        .from('workspaces')
        .update({ is_available: !workspace.is_available })
        .eq('id', workspace.id)

      if (error) throw error

      showSuccess(`Workspace "${workspace.name}" ${!workspace.is_available ? 'enabled' : 'disabled'} successfully`)
      fetchWorkspaces()
    } catch (error) {
      console.error('Error updating workspace:', error)
      showError('Error updating workspace: ' + error.message)
    }
  }

  const filtered = workspaces.filter((ws) => {
    if (filter === 'listed') return ws.workspace_approved === true
    if (filter === 'pending') return ws.workspace_approved === null
    if (filter === 'rejected') return ws.workspace_approved === false
    return true
  })

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
        marginBottom: '24px',
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        flexWrap: 'wrap',
        gap: '20px',
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
          }}>
            All Workspaces
          </h1>
          <p style={{ color: '#64748b', fontSize: '16px', fontWeight: '500' }}>
            View listing status, legal documents, and availability
          </p>
        </div>
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
          <Link
            to="/workspace-requests"
            style={{
              padding: '12px 20px',
              background: 'white',
              color: '#6366f1',
              border: '1px solid #c7d2fe',
              borderRadius: '12px',
              fontSize: '14px',
              fontWeight: '600',
              textDecoration: 'none',
            }}
          >
            Pending Requests
          </Link>
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
            }}
          >
            <RefreshCw size={18} />
            Refresh
          </button>
        </div>
      </div>

      <div style={{ display: 'flex', gap: 8, marginBottom: 24, flexWrap: 'wrap' }}>
        {FILTERS.map((f) => (
          <button
            key={f.id}
            onClick={() => setFilter(f.id)}
            style={{
              padding: '8px 16px',
              borderRadius: 999,
              border: filter === f.id ? 'none' : '1px solid #e2e8f0',
              background: filter === f.id ? 'linear-gradient(135deg, #6366f1, #8b5cf6)' : 'white',
              color: filter === f.id ? 'white' : '#64748b',
              fontWeight: 600,
              fontSize: 13,
              cursor: 'pointer',
            }}
          >
            {f.label}
            <span style={{ marginLeft: 6, opacity: 0.85 }}>
              ({f.id === 'all' ? workspaces.length : workspaces.filter((ws) => {
                if (f.id === 'listed') return ws.workspace_approved === true
                if (f.id === 'pending') return ws.workspace_approved === null
                if (f.id === 'rejected') return ws.workspace_approved === false
                return true
              }).length})
            </span>
          </button>
        ))}
      </div>

      {filtered.length === 0 ? (
        <EmptyState
          icon={Building2}
          title="No workspaces in this view"
          message={filter === 'pending' ? 'Pending listings appear in Workspace Requests' : 'Workspaces will appear here once owners create them'}
        />
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          {filtered.map((workspace) => {
            const status = approvalMeta(workspace)
            return (
              <div
                key={workspace.id}
                style={{
                  backgroundColor: 'white',
                  padding: '24px',
                  borderRadius: '12px',
                  boxShadow: '0 2px 8px rgba(0, 0, 0, 0.08)',
                  border: `1px solid ${status.border}33`,
                  borderLeft: `4px solid ${status.border}`,
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', gap: '20px', flexWrap: 'wrap' }}>
                  <div style={{ flex: 1, minWidth: 260 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '12px', flexWrap: 'wrap' }}>
                      <h3 style={{ fontSize: '20px', fontWeight: '600', color: '#1e293b', margin: 0 }}>
                        {workspace.name}
                      </h3>
                      <span style={{
                        padding: '4px 10px',
                        borderRadius: '6px',
                        fontSize: '11px',
                        fontWeight: '600',
                        backgroundColor: status.bg,
                        color: status.color,
                      }}>
                        {status.label}
                      </span>
                    </div>

                    <p style={{ color: '#64748b', marginBottom: '16px', fontSize: '14px', lineHeight: '1.6' }}>
                      {workspace.description || 'No description'}
                    </p>

                    <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', marginBottom: '16px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '10px', color: '#64748b', fontSize: '14px' }}>
                        <MapPin size={18} color="#94a3b8" />
                        <span>{workspace.address}, {workspace.city}</span>
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '10px', color: '#64748b', fontSize: '14px' }}>
                        <Banknote size={18} color="#94a3b8" />
                        <span style={{ fontWeight: '600', color: '#1e293b' }}>
                          PKR {workspace.price_per_day}/day
                        </span>
                      </div>
                      {workspace.legal_document_url ? (
                        <a
                          href={workspace.legal_document_url}
                          target="_blank"
                          rel="noreferrer"
                          style={{ display: 'inline-flex', alignItems: 'center', gap: 8, color: '#6366f1', fontSize: 14, fontWeight: 600, textDecoration: 'none' }}
                        >
                          <FileText size={16} /> View legal document <ExternalLink size={14} />
                        </a>
                      ) : (
                        <span style={{ color: '#ef4444', fontSize: 13 }}>No legal document uploaded</span>
                      )}
                    </div>

                    <div style={{ fontSize: '12px', color: '#94a3b8', paddingTop: '12px', borderTop: '1px solid #f1f5f9' }}>
                      Created: {format(new Date(workspace.created_at), 'MMM dd, yyyy')}
                    </div>
                  </div>

                  <div style={{ display: 'flex', flexDirection: 'column', gap: 8, flexShrink: 0 }}>
                    {workspace.workspace_approved === null && (
                      <Link
                        to="/workspace-requests"
                        style={{
                          padding: '10px 20px',
                          background: 'linear-gradient(135deg, #f59e0b, #d97706)',
                          color: 'white',
                          borderRadius: '8px',
                          fontSize: '14px',
                          fontWeight: '600',
                          textDecoration: 'none',
                          textAlign: 'center',
                        }}
                      >
                        Review Request
                      </Link>
                    )}
                    <button
                      onClick={() => handleToggleAvailability(workspace)}
                      disabled={workspace.workspace_approved !== true}
                      style={{
                        padding: '10px 20px',
                        backgroundColor: workspace.is_available ? '#fee2e2' : '#d1fae5',
                        color: workspace.is_available ? '#dc2626' : '#059669',
                        border: 'none',
                        borderRadius: '8px',
                        cursor: workspace.workspace_approved === true ? 'pointer' : 'not-allowed',
                        fontSize: '14px',
                        fontWeight: '600',
                        opacity: workspace.workspace_approved === true ? 1 : 0.5,
                      }}
                    >
                      {workspace.is_available ? 'Disable' : 'Enable'}
                    </button>
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}

export default Workspaces
