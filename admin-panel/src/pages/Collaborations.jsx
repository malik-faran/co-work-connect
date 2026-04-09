import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { format } from 'date-fns'
import { Users, RefreshCw, Search, Trash2, CheckCircle, XCircle } from 'lucide-react'
import Loading from '../components/Loading'
import EmptyState from '../components/EmptyState'
import { showSuccess, showError } from '../utils/toast'

const Collaborations = () => {
  const [collaborations, setCollaborations] = useState([])
  const [loading, setLoading] = useState(true)
  const [searchQuery, setSearchQuery] = useState('')
  const [filter, setFilter] = useState('all') // all, open, in_progress, completed, cancelled
  const [deletingId, setDeletingId] = useState(null)

  useEffect(() => {
    fetchCollaborations()
  }, [filter])

  const fetchCollaborations = async () => {
    try {
      setLoading(true)
      let query = supabase
        .from('collaborations')
        .select(`
          *,
          users(name, email)
        `)
        .order('created_at', { ascending: false })

      if (filter !== 'all') {
        query = query.eq('status', filter)
      }

      const { data, error } = await query

      if (error) throw error
      setCollaborations(data || [])
    } catch (error) {
      console.error('Error fetching collaborations:', error)
      showError('Failed to load collaborations: ' + error.message)
    } finally {
      setLoading(false)
    }
  }

  const handleDeleteCollaboration = async (collabId, title) => {
    if (!confirm(`Are you sure you want to delete collaboration "${title}"?\n\nThis action cannot be undone.`)) {
      return
    }

    try {
      setDeletingId(collabId)
      const { error } = await supabase
        .from('collaborations')
        .delete()
        .eq('id', collabId)

      if (error) throw error

      showSuccess('Collaboration deleted successfully')
      fetchCollaborations()
    } catch (error) {
      console.error('Error deleting collaboration:', error)
      showError('Failed to delete collaboration: ' + error.message)
    } finally {
      setDeletingId(null)
    }
  }

  const handleUpdateStatus = async (collabId, newStatus) => {
    try {
      const { error } = await supabase
        .from('collaborations')
        .update({ status: newStatus })
        .eq('id', collabId)

      if (error) throw error

      showSuccess(`Collaboration status updated to ${newStatus}`)
      fetchCollaborations()
    } catch (error) {
      console.error('Error updating status:', error)
      showError('Failed to update status: ' + error.message)
    }
  }

  const filteredCollaborations = collaborations.filter(collab => {
    if (!searchQuery) return true
    const query = searchQuery.toLowerCase()
    return (
      collab.title?.toLowerCase().includes(query) ||
      collab.description?.toLowerCase().includes(query) ||
      collab.user_name?.toLowerCase().includes(query)
    )
  })

  const getStatusColor = (status) => {
    switch (status) {
      case 'open': return '#3b82f6'
      case 'in_progress': return '#f59e0b'
      case 'completed': return '#10b981'
      case 'cancelled': return '#ef4444'
      default: return '#6b7280'
    }
  }

  if (loading) {
    return <Loading message="Loading collaborations..." />
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
            Collaborations
          </h1>
          <p style={{ 
            color: '#64748b', 
            fontSize: '16px',
            fontWeight: '500'
          }}>
            Manage collaboration requests and projects
          </p>
        </div>
        
        <div style={{ 
          display: 'flex', 
          gap: '12px',
          alignItems: 'center'
        }}>
          <button
            onClick={fetchCollaborations}
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
            placeholder="Search by title, description, or user..."
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
          <option value="open">Open</option>
          <option value="in_progress">In Progress</option>
          <option value="completed">Completed</option>
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
          {filteredCollaborations.length} {filteredCollaborations.length === 1 ? 'collaboration' : 'collaborations'}
        </div>
      </div>

      {/* Collaborations List */}
      {filteredCollaborations.length === 0 ? (
        <EmptyState
          icon={Users}
          title={searchQuery ? "No collaborations found" : "No collaborations yet"}
          message={searchQuery ? "Try adjusting your search or filter" : "Collaborations will appear here once users create them"}
        />
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          {filteredCollaborations.map((collab) => (
            <div
              key={collab.id}
              style={{
                background: 'linear-gradient(135deg, rgba(255, 255, 255, 0.95) 0%, rgba(255, 255, 255, 0.9) 100%)',
                backdropFilter: 'blur(10px)',
                padding: '24px',
                borderRadius: '16px',
                boxShadow: '0 4px 20px rgba(0, 0, 0, 0.08)',
                border: '1px solid rgba(255, 255, 255, 0.2)',
                borderLeft: `4px solid ${getStatusColor(collab.status)}`,
                transition: 'all 0.3s'
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
                      fontSize: '20px', 
                      fontWeight: '600', 
                      color: '#1e293b' 
                    }}>
                      {collab.title}
                    </h3>
                    <span style={{
                      padding: '6px 12px',
                      borderRadius: '6px',
                      fontSize: '11px',
                      fontWeight: '600',
                      backgroundColor: getStatusColor(collab.status) + '20',
                      color: getStatusColor(collab.status),
                      textTransform: 'uppercase',
                      letterSpacing: '0.5px'
                    }}>
                      {collab.status?.replaceAll('_', ' ')}
                    </span>
                    <span style={{
                      padding: '6px 12px',
                      borderRadius: '6px',
                      fontSize: '11px',
                      fontWeight: '600',
                      backgroundColor: collab.collaboration_type === 'need_help' ? '#3b82f620' : '#8b5cf620',
                      color: collab.collaboration_type === 'need_help' ? '#3b82f6' : '#8b5cf6'
                    }}>
                      {collab.collaboration_type === 'need_help' ? 'Need Help' : 'Offering Help'}
                    </span>
                  </div>

                  <p style={{ 
                    color: '#64748b', 
                    marginBottom: '16px',
                    fontSize: '14px',
                    lineHeight: '1.6'
                  }}>
                    {collab.description}
                  </p>

                  <div style={{ 
                    display: 'flex', 
                    flexWrap: 'wrap',
                    gap: '12px', 
                    marginBottom: '12px' 
                  }}>
                    {collab.required_skills && collab.required_skills.length > 0 && (
                      <div>
                        <span style={{ fontSize: '12px', color: '#94a3b8', fontWeight: '600', textTransform: 'uppercase' }}>Skills: </span>
                        {collab.required_skills.map((skill, idx) => (
                          <span key={idx} style={{
                            padding: '4px 8px',
                            marginLeft: '4px',
                            borderRadius: '4px',
                            fontSize: '11px',
                            backgroundColor: '#f1f5f9',
                            color: '#475569'
                          }}>
                            {skill}
                          </span>
                        ))}
                      </div>
                    )}
                    {collab.budget && (
                      <div style={{ fontSize: '12px', color: '#64748b' }}>
                        <strong>Budget:</strong> {collab.budget}
                      </div>
                    )}
                  </div>

                  <div style={{ 
                    fontSize: '12px', 
                    color: '#94a3b8',
                    paddingTop: '12px',
                    borderTop: '1px solid #f1f5f9',
                    display: 'flex',
                    gap: '16px',
                    flexWrap: 'wrap'
                  }}>
                    <span>By: <strong>{collab.user_name || collab.users?.name || 'Unknown'}</strong></span>
                    <span>•</span>
                    <span>{format(new Date(collab.created_at), 'MMM dd, yyyy')}</span>
                  </div>
                </div>

                <div style={{ 
                  display: 'flex', 
                  gap: '8px',
                  flexShrink: 0,
                  flexDirection: 'column'
                }}>
                  {collab.status === 'open' && (
                    <>
                      <button
                        onClick={() => handleUpdateStatus(collab.id, 'in_progress')}
                        style={{
                          padding: '8px 16px',
                          background: 'linear-gradient(135deg, #f59e0b 0%, #d97706 100%)',
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
                        Start
                      </button>
                      <button
                        onClick={() => handleUpdateStatus(collab.id, 'cancelled')}
                        style={{
                          padding: '8px 16px',
                          background: 'linear-gradient(135deg, #ef4444 0%, #dc2626 100%)',
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
                        <XCircle size={14} />
                        Cancel
                      </button>
                    </>
                  )}
                  {collab.status === 'in_progress' && (
                    <button
                      onClick={() => handleUpdateStatus(collab.id, 'completed')}
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
                      Complete
                    </button>
                  )}
                  <button
                    onClick={() => handleDeleteCollaboration(collab.id, collab.title)}
                    disabled={deletingId === collab.id}
                    style={{
                      padding: '8px 16px',
                      background: deletingId === collab.id 
                        ? 'linear-gradient(135deg, #94a3b8 0%, #64748b 100%)' 
                        : 'linear-gradient(135deg, #ef4444 0%, #dc2626 100%)',
                      color: 'white',
                      border: 'none',
                      borderRadius: '8px',
                      cursor: deletingId === collab.id ? 'not-allowed' : 'pointer',
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
                    {deletingId === collab.id ? 'Deleting...' : 'Delete'}
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

export default Collaborations
