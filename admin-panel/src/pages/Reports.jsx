import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { format } from 'date-fns'
import { Flag, RefreshCw, Check, X, Eye, ExternalLink } from 'lucide-react'
import Loading from '../components/Loading'
import EmptyState from '../components/EmptyState'
import { showSuccess, showError } from '../utils/toast'

const REPORT_TYPE_LABELS = {
  harassment: 'Harassment',
  fraud: 'Fraud / Scam',
  fake_listing: 'Fake Listing',
  payment_issue: 'Payment Issue',
  inappropriate_content: 'Inappropriate Content',
  spam: 'Spam',
  safety: 'Safety Concern',
  other: 'Other',
}

const STATUS_COLORS = {
  pending: { bg: '#fef3c7', color: '#b45309' },
  under_review: { bg: '#dbeafe', color: '#1d4ed8' },
  resolved: { bg: '#d1fae5', color: '#047857' },
  dismissed: { bg: '#f1f5f9', color: '#64748b' },
}

const Reports = () => {
  const [reports, setReports] = useState([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('pending')
  const [selected, setSelected] = useState(null)
  const [note, setNote] = useState('')
  const [staffAction, setStaffAction] = useState('none')
  const [processing, setProcessing] = useState(false)

  useEffect(() => {
    fetchReports()
  }, [filter])

  const fetchReports = async () => {
    try {
      setLoading(true)

      let query = supabase
        .from('user_reports')
        .select(`
          *,
          reporter:users!user_reports_reporter_id_fkey(name, email, role),
          reported_user:users!user_reports_reported_user_id_fkey(name, email),
          workspaces(name, city),
          bookings(workspace_name, status)
        `)
        .order('created_at', { ascending: false })

      if (filter !== 'all') query = query.eq('status', filter)

      let { data, error } = await query

      if (error) {
        const plain = await supabase
          .from('user_reports')
          .select('*')
          .order('created_at', { ascending: false })

        if (plain.error) {
          if (plain.error.message?.includes('user_reports') || plain.error.code === '42P01') {
            throw new Error('user_reports table missing. Run supabase/22_user_reports.sql in Supabase.')
          }
          throw plain.error
        }

        let rows = plain.data || []
        if (filter !== 'all') rows = rows.filter((r) => r.status === filter)

        const userIds = [...new Set([
          ...rows.map((r) => r.reporter_id),
          ...rows.map((r) => r.reported_user_id),
        ].filter(Boolean))]

        const workspaceIds = [...new Set(rows.map((r) => r.workspace_id).filter(Boolean))]
        const bookingIds = [...new Set(rows.map((r) => r.booking_id).filter(Boolean))]

        const [{ data: users }, { data: workspaces }, { data: bookings }] = await Promise.all([
          userIds.length
            ? supabase.from('users').select('id, name, email, role').in('id', userIds)
            : Promise.resolve({ data: [] }),
          workspaceIds.length
            ? supabase.from('workspaces').select('id, name, city').in('id', workspaceIds)
            : Promise.resolve({ data: [] }),
          bookingIds.length
            ? supabase.from('bookings').select('id, workspace_name, status').in('id', bookingIds)
            : Promise.resolve({ data: [] }),
        ])

        const userMap = Object.fromEntries((users || []).map((u) => [u.id, u]))
        const wsMap = Object.fromEntries((workspaces || []).map((w) => [w.id, w]))
        const bookingMap = Object.fromEntries((bookings || []).map((b) => [b.id, b]))

        data = rows.map((r) => ({
          ...r,
          reporter: userMap[r.reporter_id] || null,
          reported_user: r.reported_user_id ? userMap[r.reported_user_id] : null,
          workspaces: r.workspace_id ? wsMap[r.workspace_id] : null,
          bookings: r.booking_id ? bookingMap[r.booking_id] : null,
        }))
        error = null
      }

      if (error) throw error
      setReports(data || [])
    } catch (e) {
      showError(e?.message || String(e))
    } finally {
      setLoading(false)
    }
  }

  const processReport = async (status) => {
    if (!selected) return
    if ((status === 'resolved' || status === 'dismissed') && !note.trim()) {
      showError('Please add a resolution note for the reporter')
      return
    }

    setProcessing(true)
    try {
      const { error } = await supabase.rpc('process_user_report', {
        p_report_id: selected.id,
        p_status: status,
        p_note: note.trim() || null,
        p_staff_action: status === 'resolved' ? staffAction : 'none',
      })
      if (error) throw error

      const labels = {
        under_review: 'Report marked under review',
        resolved: 'Report resolved — reporter notified',
        dismissed: 'Report dismissed — reporter notified',
      }
      showSuccess(labels[status])
      setSelected(null)
      setNote('')
      setStaffAction('none')
      fetchReports()
    } catch (e) {
      showError(e.message)
    } finally {
      setProcessing(false)
    }
  }

  const openReport = (report) => {
    setSelected(report)
    setNote(report.resolution_note || '')
    setStaffAction('none')
  }

  if (loading) return <Loading message="Loading reports..." />

  return (
    <div className="fade-in">
      <div style={{ marginBottom: '32px' }}>
        <h1 style={{ fontSize: '32px', fontWeight: '800', marginBottom: '8px' }}>User Reports</h1>
        <p style={{ color: '#64748b' }}>
          Review reports submitted by users and owners. Take action and notify the reporter.
        </p>
      </div>

      <div style={{ display: 'flex', gap: '8px', marginBottom: '24px', flexWrap: 'wrap' }}>
        {['pending', 'under_review', 'resolved', 'dismissed', 'all'].map((f) => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            style={{
              padding: '10px 16px', borderRadius: '8px', border: 'none', cursor: 'pointer',
              background: filter === f ? '#6366f1' : '#f1f5f9',
              color: filter === f ? 'white' : '#475569', fontWeight: '600', textTransform: 'capitalize',
            }}
          >
            {f.replace('_', ' ')}
          </button>
        ))}
        <button
          onClick={fetchReports}
          style={{
            marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: '6px',
            padding: '10px 16px', border: '1px solid #e2e8f0', borderRadius: '8px',
            background: 'white', cursor: 'pointer',
          }}
        >
          <RefreshCw size={16} /> Refresh
        </button>
      </div>

      {reports.length === 0 ? (
        <EmptyState
          icon={Flag}
          title="No reports"
          message={`No ${filter === 'all' ? '' : filter.replace('_', ' ')} reports found.`}
        />
      ) : (
        <div style={{ display: 'grid', gap: '12px' }}>
          {reports.map((r) => {
            const statusStyle = STATUS_COLORS[r.status] || STATUS_COLORS.pending
            return (
              <div
                key={r.id}
                style={{
                  background: 'white', padding: '20px', borderRadius: '12px',
                  boxShadow: '0 2px 12px rgba(0,0,0,0.06)', cursor: 'pointer',
                }}
                onClick={() => openReport(r)}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', flexWrap: 'wrap', gap: '12px' }}>
                  <div style={{ flex: 1, minWidth: '200px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '6px' }}>
                      <Flag size={16} color="#6366f1" />
                      <strong>{r.subject}</strong>
                      <span style={{
                        fontSize: '12px', padding: '2px 8px', borderRadius: '6px',
                        background: statusStyle.bg, color: statusStyle.color, fontWeight: '600',
                      }}>
                        {r.status.replace('_', ' ')}
                      </span>
                    </div>
                    <div style={{ color: '#64748b', fontSize: '14px' }}>
                      {REPORT_TYPE_LABELS[r.report_type] || r.report_type}
                      {' · '}
                      by {r.reporter?.name || 'Unknown'} ({r.reporter_role})
                    </div>
                    <p style={{
                      margin: '8px 0 0', fontSize: '14px', color: '#334155',
                      display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden',
                    }}>
                      {r.description}
                    </p>
                  </div>
                  <div style={{ textAlign: 'right', fontSize: '13px', color: '#94a3b8' }}>
                    {format(new Date(r.created_at), 'MMM d, yyyy HH:mm')}
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      )}

      {selected && (
        <div style={{
          position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          zIndex: 1000, padding: '16px',
        }}>
          <div style={{
            background: 'white', borderRadius: '16px', maxWidth: '640px',
            width: '100%', maxHeight: '90vh', overflow: 'auto', padding: '28px',
          }}>
            <h2 style={{ fontSize: '22px', fontWeight: '700', marginBottom: '8px' }}>{selected.subject}</h2>
            <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', marginBottom: '16px' }}>
              <span style={{ fontSize: '13px', padding: '4px 10px', borderRadius: '6px', background: '#eef2ff', color: '#4f46e5' }}>
                {REPORT_TYPE_LABELS[selected.report_type] || selected.report_type}
              </span>
              <span style={{ fontSize: '13px', padding: '4px 10px', borderRadius: '6px', background: '#f1f5f9', color: '#475569' }}>
                {selected.status.replace('_', ' ')}
              </span>
            </div>

            <div style={{ background: '#f8fafc', borderRadius: '10px', padding: '16px', marginBottom: '16px' }}>
              <div style={{ fontSize: '13px', color: '#64748b', marginBottom: '4px' }}>Reporter</div>
              <div style={{ fontWeight: '600' }}>
                {selected.reporter?.name} ({selected.reporter?.email}) — {selected.reporter_role}
              </div>
            </div>

            <div style={{ marginBottom: '16px' }}>
              <div style={{ fontSize: '13px', color: '#64748b', marginBottom: '4px' }}>Description</div>
              <p style={{ margin: 0, lineHeight: 1.6, whiteSpace: 'pre-wrap' }}>{selected.description}</p>
            </div>

            {(selected.reported_user || selected.workspaces || selected.bookings) && (
              <div style={{ marginBottom: '16px', display: 'grid', gap: '8px' }}>
                {selected.reported_user && (
                  <div style={{ fontSize: '14px' }}>
                    <strong>Reported user:</strong> {selected.reported_user.name} ({selected.reported_user.email})
                  </div>
                )}
                {selected.workspaces && (
                  <div style={{ fontSize: '14px' }}>
                    <strong>Workspace:</strong> {selected.workspaces.name} — {selected.workspaces.city}
                  </div>
                )}
                {selected.bookings && (
                  <div style={{ fontSize: '14px' }}>
                    <strong>Booking:</strong> {selected.bookings.workspace_name} ({selected.bookings.status})
                  </div>
                )}
              </div>
            )}

            {Array.isArray(selected.evidence_urls) && selected.evidence_urls.length > 0 && (
              <div style={{ marginBottom: '16px' }}>
                <div style={{ fontSize: '13px', color: '#64748b', marginBottom: '8px' }}>Evidence</div>
                <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                  {selected.evidence_urls.map((url, i) => (
                    <a
                      key={i}
                      href={url}
                      target="_blank"
                      rel="noreferrer"
                      style={{
                        display: 'flex', alignItems: 'center', gap: '4px',
                        fontSize: '13px', color: '#6366f1',
                      }}
                    >
                      <ExternalLink size={14} /> Image {i + 1}
                    </a>
                  ))}
                </div>
              </div>
            )}

            {!['resolved', 'dismissed'].includes(selected.status) && (
              <>
                <textarea
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                  placeholder="Resolution note (sent to reporter on resolve/dismiss)"
                  rows={3}
                  style={{
                    width: '100%', padding: '12px', borderRadius: '8px',
                    border: '1px solid #e2e8f0', marginBottom: '12px', resize: 'vertical',
                  }}
                />

                {selected.workspace_id && (
                  <select
                    value={staffAction}
                    onChange={(e) => setStaffAction(e.target.value)}
                    style={{
                      width: '100%', padding: '10px', borderRadius: '8px',
                      border: '1px solid #e2e8f0', marginBottom: '16px',
                    }}
                  >
                    <option value="none">No additional action</option>
                    <option value="workspace_hidden">Hide workspace listing</option>
                  </select>
                )}

                <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                  {selected.status === 'pending' && (
                    <button
                      onClick={() => processReport('under_review')}
                      disabled={processing}
                      style={{
                        display: 'flex', alignItems: 'center', gap: '6px',
                        padding: '10px 16px', borderRadius: '8px', border: 'none',
                        background: '#3b82f6', color: 'white', cursor: 'pointer', fontWeight: '600',
                      }}
                    >
                      <Eye size={16} /> Under Review
                    </button>
                  )}
                  <button
                    onClick={() => processReport('resolved')}
                    disabled={processing}
                    style={{
                      display: 'flex', alignItems: 'center', gap: '6px',
                      padding: '10px 16px', borderRadius: '8px', border: 'none',
                      background: '#10b981', color: 'white', cursor: 'pointer', fontWeight: '600',
                    }}
                  >
                    <Check size={16} /> Resolve
                  </button>
                  <button
                    onClick={() => processReport('dismissed')}
                    disabled={processing}
                    style={{
                      display: 'flex', alignItems: 'center', gap: '6px',
                      padding: '10px 16px', borderRadius: '8px', border: 'none',
                      background: '#ef4444', color: 'white', cursor: 'pointer', fontWeight: '600',
                    }}
                  >
                    <X size={16} /> Dismiss
                  </button>
                </div>
              </>
            )}

            {selected.resolution_note && ['resolved', 'dismissed'].includes(selected.status) && (
              <div style={{ background: '#f0fdf4', padding: '12px', borderRadius: '8px', marginBottom: '16px' }}>
                <div style={{ fontSize: '13px', color: '#64748b' }}>Resolution note</div>
                <p style={{ margin: '4px 0 0' }}>{selected.resolution_note}</p>
              </div>
            )}

            <button
              onClick={() => setSelected(null)}
              style={{
                marginTop: '16px', padding: '10px 20px', borderRadius: '8px',
                border: '1px solid #e2e8f0', background: 'white', cursor: 'pointer', width: '100%',
              }}
            >
              Close
            </button>
          </div>
        </div>
      )}
    </div>
  )
}

export default Reports
