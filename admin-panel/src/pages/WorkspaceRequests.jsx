import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { Check, X, RefreshCw, Building2, FileText, MapPin, ClipboardCheck, Mail, Phone, AlertCircle } from 'lucide-react'
import Loading from '../components/Loading'
import EmptyState from '../components/EmptyState'
import { showSuccess, showError } from '../utils/toast'
import { recordStaffAction } from '../lib/auditLog'
import { format } from 'date-fns'

const WorkspaceRequests = () => {
  const [requests, setRequests] = useState([])
  const [loading, setLoading] = useState(true)
  const [selected, setSelected] = useState(null)
  const [rejectionReason, setRejectionReason] = useState('')
  const [showRejectForm, setShowRejectForm] = useState(false)
  const [docVerified, setDocVerified] = useState(false)
  const [detailsVerified, setDetailsVerified] = useState(false)

  useEffect(() => {
    fetchRequests()
  }, [])

  const fetchRequests = async () => {
    try {
      setLoading(true)
      const { data: workspaces, error } = await supabase
        .from('workspaces')
        .select('*')
        .is('workspace_approved', null)
        .order('created_at', { ascending: false })

      if (error) {
        if (error.message?.includes('workspace_approved')) {
          showError('Run supabase/18_owner_workspace_approval.sql in Supabase SQL Editor first.')
        }
        throw error
      }

      const ownerIds = [...new Set((workspaces || []).map((w) => w.owner_id).filter(Boolean))]
      let ownerMap = {}
      if (ownerIds.length) {
        const { data: owners } = await supabase
          .from('users')
          .select('id, name, email, phone')
          .in('id', ownerIds)
        ownerMap = Object.fromEntries((owners || []).map((o) => [o.id, o]))
      }

      setRequests((workspaces || []).map((w) => ({ ...w, owner: ownerMap[w.owner_id] })))
    } catch (error) {
      console.error('Error fetching workspace requests:', error)
      showError('Failed to load workspace requests: ' + error.message)
    } finally {
      setLoading(false)
    }
  }

  const openReview = (ws) => {
    setSelected(ws)
    setShowRejectForm(false)
    setRejectionReason('')
    setDocVerified(false)
    setDetailsVerified(false)
  }

  const handleApprove = async (workspace) => {
    if (!workspace.legal_document_url) {
      showError('Cannot approve without a legal document')
      return
    }
    try {
      const { error } = await supabase
        .from('workspaces')
        .update({ workspace_approved: true, is_available: true, updated_at: new Date().toISOString() })
        .eq('id', workspace.id)

      if (error) throw error

      await supabase.from('notifications').insert({
        user_id: workspace.owner_id,
        title: 'Workspace Approved!',
        message: `Your workspace "${workspace.name}" has been approved and is now listed for bookings.`,
        type: 'workspace_approved',
        is_read: false,
        created_at: new Date().toISOString(),
      })

      showSuccess(`Workspace "${workspace.name}" approved and listed`)
      await recordStaffAction({
        action: 'workspace_approved',
        entityType: 'workspace',
        entityId: workspace.id,
        summary: `Approved workspace: ${workspace.name}`,
        details: { owner_id: workspace.owner_id },
      })
      setSelected(null)
      fetchRequests()
    } catch (error) {
      showError('Error approving workspace: ' + error.message)
    }
  }

  const handleReject = async (workspace) => {
    const reason = rejectionReason.trim() || 'Your legal document could not be verified.'
    try {
      const { error } = await supabase
        .from('workspaces')
        .update({ workspace_approved: false, is_available: false, updated_at: new Date().toISOString() })
        .eq('id', workspace.id)

      if (error) throw error

      await supabase.from('notifications').insert({
        user_id: workspace.owner_id,
        title: 'Workspace Listing Rejected',
        message: reason,
        type: 'workspace_rejected',
        is_read: false,
        created_at: new Date().toISOString(),
        metadata: { reason },
      })

      showSuccess(`Workspace "${workspace.name}" rejected`)
      await recordStaffAction({
        action: 'workspace_rejected',
        entityType: 'workspace',
        entityId: workspace.id,
        summary: `Rejected workspace: ${workspace.name}`,
        details: { reason },
      })
      setSelected(null)
      setShowRejectForm(false)
      setRejectionReason('')
      fetchRequests()
    } catch (error) {
      showError('Error rejecting workspace: ' + error.message)
    }
  }

  const isPdf = (url) => url?.toLowerCase().includes('.pdf')

  if (loading) return <Loading message="Loading workspace requests..." />

  return (
    <div className="fade-in">
      <div style={{
        background: 'linear-gradient(135deg, rgba(255, 255, 255, 0.95) 0%, rgba(255, 255, 255, 0.9) 100%)',
        backdropFilter: 'blur(10px)',
        padding: '32px',
        borderRadius: '20px',
        boxShadow: '0 8px 32px rgba(0, 0, 0, 0.08)',
        border: '1px solid rgba(255, 255, 255, 0.2)',
        marginBottom: '32px',
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
            background: 'linear-gradient(135deg, #f59e0b 0%, #d97706 100%)',
            WebkitBackgroundClip: 'text',
            WebkitTextFillColor: 'transparent',
            backgroundClip: 'text',
            marginBottom: '12px',
          }}>
            Workspace Listing Requests
          </h1>
          <p style={{ color: '#64748b', fontSize: '16px', fontWeight: '500' }}>
            Review legal/ownership documents before workspaces go live
          </p>
        </div>
        <button
          onClick={fetchRequests}
          style={{
            padding: '12px 20px',
            background: 'linear-gradient(135deg, #f59e0b 0%, #d97706 100%)',
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

      {requests.length === 0 ? (
        <EmptyState
          icon={Building2}
          title="No pending workspace requests"
          message="New workspace listings with legal documents will appear here after owners submit them"
        />
      ) : (
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fill, minmax(min(380px, 100%), 1fr))',
          gap: '24px',
        }}>
          {requests.map((ws) => (
            <div
              key={ws.id}
              style={{
                background: 'white',
                padding: '24px',
                borderRadius: '20px',
                boxShadow: '0 8px 32px rgba(0, 0, 0, 0.05)',
                border: '1px solid #e2e8f0',
                borderTop: '4px solid #f59e0b',
              }}
            >
              <h3 style={{ fontSize: 20, fontWeight: 700, marginBottom: 12, color: '#1e293b' }}>{ws.name}</h3>
              <div style={{ color: '#64748b', fontSize: 14, display: 'flex', alignItems: 'center', gap: 6, marginBottom: 8 }}>
                <MapPin size={14} /> {ws.address}, {ws.city}
              </div>
              <div style={{ color: '#64748b', fontSize: 13, marginBottom: 4 }}>
                Owner: {ws.owner?.name || 'Unknown'}
              </div>
              <div style={{ color: '#64748b', fontSize: 13, marginBottom: 12 }}>
                {ws.owner?.email || '—'}
              </div>
              <div style={{
                display: 'inline-block',
                padding: '4px 10px',
                borderRadius: 6,
                fontSize: 11,
                fontWeight: 600,
                background: ws.legal_document_url ? '#d1fae5' : '#fee2e2',
                color: ws.legal_document_url ? '#065f46' : '#991b1b',
                marginBottom: 16,
              }}>
                {ws.legal_document_url ? 'Document uploaded' : 'Missing document'}
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderTop: '1px solid #f1f5f9', paddingTop: 16 }}>
                <span style={{ fontSize: 11, color: '#94a3b8' }}>
                  {format(new Date(ws.created_at), 'MMM dd, yyyy')}
                </span>
                <button
                  onClick={() => openReview(ws)}
                  style={{
                    padding: '8px 16px',
                    background: 'linear-gradient(135deg, #f59e0b, #d97706)',
                    color: 'white',
                    border: 'none',
                    borderRadius: 10,
                    cursor: 'pointer',
                    fontSize: 13,
                    fontWeight: 700,
                    display: 'flex',
                    alignItems: 'center',
                    gap: 6,
                  }}
                >
                  <ClipboardCheck size={16} />
                  Review Listing
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {selected && (
        <div style={{
          position: 'fixed',
          inset: 0,
          background: 'rgba(15, 23, 42, 0.45)',
          backdropFilter: 'blur(8px)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 2000,
          padding: 20,
        }}>
          <div style={{
            background: 'white',
            width: '100%',
            maxWidth: 1000,
            maxHeight: '90vh',
            borderRadius: 24,
            overflow: 'hidden',
            display: 'flex',
            flexDirection: 'column',
          }}>
            <div style={{ padding: '24px 28px', borderBottom: '1px solid #e2e8f0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <h2 style={{ margin: 0, fontSize: 22 }}>{selected.name}</h2>
                <p style={{ margin: '6px 0 0', color: '#64748b', fontSize: 14 }}>{selected.address}, {selected.city}</p>
              </div>
              <button onClick={() => setSelected(null)} style={{ border: 'none', background: 'transparent', fontSize: 28, cursor: 'pointer', color: '#94a3b8' }}>×</button>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: 24, padding: 28, overflowY: 'auto' }}>
              <div>
                <h4 style={{ fontSize: 12, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: 1, marginBottom: 12 }}>Legal Document</h4>
                <div style={{
                  minHeight: 220,
                  border: '1px dashed #cbd5e1',
                  borderRadius: 16,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  padding: 16,
                  background: '#f8fafc',
                }}>
                  {selected.legal_document_url ? (
                    isPdf(selected.legal_document_url) ? (
                      <a href={selected.legal_document_url} target="_blank" rel="noreferrer" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12, color: '#6366f1', fontWeight: 700, textDecoration: 'none' }}>
                        <FileText size={48} />
                        Open PDF in new tab
                      </a>
                    ) : (
                      <img src={selected.legal_document_url} alt="Legal document" style={{ maxWidth: '100%', maxHeight: 280, borderRadius: 8 }} />
                    )
                  ) : (
                    <div style={{ textAlign: 'center', color: '#94a3b8' }}>
                      <AlertCircle size={40} style={{ marginBottom: 8 }} />
                      <p style={{ margin: 0 }}>No legal document uploaded</p>
                    </div>
                  )}
                </div>
              </div>

              <div>
                <h4 style={{ fontSize: 12, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: 1, marginBottom: 12 }}>Workspace Details</h4>
                <div style={{ background: '#f8fafc', borderRadius: 12, padding: 16, marginBottom: 16 }}>
                  <p style={{ fontSize: 14, color: '#475569', lineHeight: 1.6, margin: '0 0 12px' }}>{selected.description || 'No description'}</p>
                  <p style={{ fontSize: 13, color: '#64748b', margin: '0 0 6px' }}>PKR {selected.price_per_day}/day · {selected.capacity} capacity</p>
                  <p style={{ fontSize: 13, color: '#64748b', margin: 0 }}>Type: {selected.workspace_type || 'shared'}</p>
                </div>

                <h4 style={{ fontSize: 12, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: 1, marginBottom: 12 }}>Owner</h4>
                <div style={{ background: '#f8fafc', borderRadius: 12, padding: 16, display: 'flex', flexDirection: 'column', gap: 8 }}>
                  <div style={{ fontSize: 13, color: '#64748b' }}>Name: <strong style={{ color: '#1e293b' }}>{selected.owner?.name || '—'}</strong></div>
                  <div style={{ fontSize: 13, color: '#64748b', display: 'flex', alignItems: 'center', gap: 6 }}><Mail size={14} /> {selected.owner?.email || '—'}</div>
                  <div style={{ fontSize: 13, color: '#64748b', display: 'flex', alignItems: 'center', gap: 6 }}><Phone size={14} /> {selected.owner?.phone || '—'}</div>
                </div>

                <div style={{ marginTop: 20, display: 'flex', flexDirection: 'column', gap: 10 }}>
                  <label style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 14, color: '#475569', cursor: 'pointer' }}>
                    <input type="checkbox" checked={docVerified} disabled={!selected.legal_document_url} onChange={(e) => setDocVerified(e.target.checked)} />
                    Legal document verified
                  </label>
                  <label style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 14, color: '#475569', cursor: 'pointer' }}>
                    <input type="checkbox" checked={detailsVerified} onChange={(e) => setDetailsVerified(e.target.checked)} />
                    Workspace details & location confirmed
                  </label>
                </div>
              </div>
            </div>

            <div style={{ padding: '20px 28px 28px', borderTop: '1px solid #e2e8f0' }}>
              {showRejectForm ? (
                <div style={{ background: '#fef2f2', padding: 16, borderRadius: 12, border: '1px solid #fee2e2' }}>
                  <textarea
                    value={rejectionReason}
                    onChange={(e) => setRejectionReason(e.target.value)}
                    placeholder="Reason for rejection (e.g. document is unclear or does not match business address)..."
                    rows={3}
                    style={{ width: '100%', padding: 12, borderRadius: 8, border: '1px solid #fca5a5', marginBottom: 12, resize: 'none' }}
                  />
                  <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
                    <button onClick={() => setShowRejectForm(false)} style={{ padding: '8px 14px', border: 'none', background: 'transparent', cursor: 'pointer' }}>Cancel</button>
                    <button onClick={() => handleReject(selected)} style={{ padding: '8px 16px', background: '#ef4444', color: 'white', border: 'none', borderRadius: 8, cursor: 'pointer', fontWeight: 600 }}>Confirm Reject</button>
                  </div>
                </div>
              ) : (
                <div style={{ display: 'flex', gap: 12 }}>
                  <button
                    onClick={() => setShowRejectForm(true)}
                    style={{ flex: 1, padding: 14, border: '1px solid #ef4444', color: '#ef4444', background: 'white', borderRadius: 12, cursor: 'pointer', fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}
                  >
                    <X size={18} /> Reject
                  </button>
                  <button
                    onClick={() => handleApprove(selected)}
                    disabled={!selected.legal_document_url || !docVerified || !detailsVerified}
                    style={{
                      flex: 1.5,
                      padding: 14,
                      border: 'none',
                      background: selected.legal_document_url && docVerified && detailsVerified ? 'linear-gradient(135deg, #10b981, #059669)' : '#94a3b8',
                      color: 'white',
                      borderRadius: 12,
                      cursor: selected.legal_document_url && docVerified && detailsVerified ? 'pointer' : 'not-allowed',
                      fontWeight: 700,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      gap: 8,
                    }}
                  >
                    <Check size={18} /> Approve & List
                  </button>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default WorkspaceRequests
