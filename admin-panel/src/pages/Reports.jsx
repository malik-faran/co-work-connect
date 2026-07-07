import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { format } from 'date-fns'
import { Flag, RefreshCw, Check, X, Eye, ExternalLink } from 'lucide-react'
import Loading from '../components/Loading'
import {
  PageHeader,
  Panel,
  FilterTabs,
  StatusBadge,
  Btn,
  Field,
  EmptyPanel,
} from '../components/ui/PageShell'
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

const FILTER_OPTIONS = [
  { value: 'pending', label: 'Pending' },
  { value: 'under_review', label: 'Under review' },
  { value: 'resolved', label: 'Resolved' },
  { value: 'dismissed', label: 'Dismissed' },
  { value: 'all', label: 'All' },
]

const FOLLOWUPS_MIGRATION_HINT =
  'Conversation table missing. Run supabase/50_report_followups_fix.sql in Supabase SQL Editor, then refresh.'

const isFollowupsSchemaError = (err) => {
  const msg = err?.message || String(err || '')
  return (
    msg.includes('user_report_followups') ||
    err?.code === '42P01' ||
    err?.code === 'PGRST205'
  )
}

const Reports = () => {
  const [reports, setReports] = useState([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('pending')
  const [selected, setSelected] = useState(null)
  const [followups, setFollowups] = useState([])
  const [note, setNote] = useState('')
  const [staffReply, setStaffReply] = useState('')
  const [staffAction, setStaffAction] = useState('none')
  const [processing, setProcessing] = useState(false)
  const [loadingFollowups, setLoadingFollowups] = useState(false)
  const [followupsLoadError, setFollowupsLoadError] = useState('')

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
      if (selected && !(data || []).some((r) => r.id === selected.id)) {
        setSelected(null)
        setFollowups([])
      }
    } catch (e) {
      showError(e?.message || String(e))
    } finally {
      setLoading(false)
    }
  }

  const fetchFollowups = async (reportId) => {
    setLoadingFollowups(true)
    setFollowupsLoadError('')
    try {
      const { data, error } = await supabase
        .from('user_report_followups')
        .select('*, author:users!user_report_followups_author_id_fkey(name, role)')
        .eq('report_id', reportId)
        .order('created_at', { ascending: true })
      if (error) {
        const plain = await supabase
          .from('user_report_followups')
          .select('*')
          .eq('report_id', reportId)
          .order('created_at', { ascending: true })
        if (plain.error) {
          if (isFollowupsSchemaError(plain.error)) {
            setFollowupsLoadError(FOLLOWUPS_MIGRATION_HINT)
            setFollowups([])
            return
          }
          throw plain.error
        }
        setFollowups(plain.data || [])
        return
      }
      setFollowups(data || [])
    } catch (e) {
      if (isFollowupsSchemaError(e)) {
        setFollowupsLoadError(FOLLOWUPS_MIGRATION_HINT)
        setFollowups([])
        return
      }
      setFollowupsLoadError(e?.message || 'Could not load conversation')
      setFollowups([])
    } finally {
      setLoadingFollowups(false)
    }
  }

  const sendStaffReply = async () => {
    if (!selected || !staffReply.trim()) {
      showError('Enter a reply message')
      return
    }
    setProcessing(true)
    try {
      const { error } = await supabase.rpc('submit_report_staff_reply', {
        p_report_id: selected.id,
        p_message: staffReply.trim(),
      })
      if (error) throw error
      showSuccess('Reply sent to reporter')
      setStaffReply('')
      await fetchFollowups(selected.id)
      fetchReports()
    } catch (e) {
      if (isFollowupsSchemaError(e)) {
        setFollowupsLoadError(FOLLOWUPS_MIGRATION_HINT)
        showError(FOLLOWUPS_MIGRATION_HINT)
        return
      }
      showError(e.message)
    } finally {
      setProcessing(false)
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
      setFollowups([])
      setNote('')
      setStaffReply('')
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
    setStaffReply('')
    setStaffAction('none')
    fetchFollowups(report.id)
  }

  const pendingCount = reports.filter((r) => r.status === 'pending').length

  if (loading) return <Loading message="Loading reports..." />

  return (
    <div className="fade-in">
      <PageHeader
        title="User Reports"
        subtitle="Review cases from users and owners. Reply, investigate, and close with a resolution note."
        badge={pendingCount > 0 ? `${pendingCount} pending` : null}
        actions={
          <Btn variant="secondary" icon={RefreshCw} onClick={fetchReports}>
            Refresh
          </Btn>
        }
      />

      <FilterTabs options={FILTER_OPTIONS} value={filter} onChange={setFilter} />

      {reports.length === 0 ? (
        <Panel>
          <EmptyPanel
            icon={Flag}
            title="No reports"
            message={`No ${filter === 'all' ? '' : filter.replace('_', ' ')} reports found.`}
          />
        </Panel>
      ) : (
        <div className="reports-layout">
          <Panel padding={false}>
            <div style={{ padding: '16px 16px 8px', borderBottom: '1px solid var(--border)' }}>
              <strong style={{ fontSize: 14 }}>{reports.length} case{reports.length !== 1 ? 's' : ''}</strong>
            </div>
            <div className="report-list" style={{ padding: 12 }}>
              {reports.map((r) => (
                <button
                  key={r.id}
                  type="button"
                  className={`report-card ${selected?.id === r.id ? 'is-selected' : ''}`}
                  onClick={() => openReport(r)}
                  style={{ textAlign: 'left', width: '100%' }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, marginBottom: 8 }}>
                    <strong style={{ fontSize: 14, lineHeight: 1.4 }}>{r.subject}</strong>
                    <StatusBadge status={r.status} map={STATUS_COLORS} />
                  </div>
                  <div style={{ fontSize: 12, color: 'var(--text-secondary)', marginBottom: 6 }}>
                    {REPORT_TYPE_LABELS[r.report_type] || r.report_type}
                    {' · '}
                    {r.reporter?.name || 'Unknown'}
                  </div>
                  <p style={{
                    margin: 0,
                    fontSize: 13,
                    color: 'var(--text-secondary)',
                    display: '-webkit-box',
                    WebkitLineClamp: 2,
                    WebkitBoxOrient: 'vertical',
                    overflow: 'hidden',
                  }}>
                    {r.description}
                  </p>
                  <div style={{ fontSize: 11, color: 'var(--text-tertiary)', marginTop: 8 }}>
                    {format(new Date(r.created_at), 'MMM d, yyyy · HH:mm')}
                  </div>
                </button>
              ))}
            </div>
          </Panel>

          <Panel>
            {!selected ? (
              <EmptyPanel
                icon={Flag}
                title="Select a report"
                message="Choose a case from the list to view details, reply to the reporter, and take action."
              />
            ) : (
              <>
                <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, marginBottom: 16, flexWrap: 'wrap' }}>
                  <div>
                    <h2 style={{ fontSize: 20, fontWeight: 800, letterSpacing: '-0.02em', marginBottom: 8 }}>
                      {selected.subject}
                    </h2>
                    <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                      <span className="badge badge--primary">
                        {REPORT_TYPE_LABELS[selected.report_type] || selected.report_type}
                      </span>
                      <StatusBadge status={selected.status} map={STATUS_COLORS} />
                    </div>
                  </div>
                  <Btn variant="ghost" size="sm" onClick={() => { setSelected(null); setFollowups([]) }}>
                    Clear
                  </Btn>
                </div>

                <div className="report-detail-grid" style={{ marginBottom: 16 }}>
                  <div className="info-tile">
                    <div className="info-tile__label">Reporter</div>
                    <div className="info-tile__value">
                      {selected.reporter?.name || 'Unknown'}
                    </div>
                    <div style={{ fontSize: 12, color: 'var(--text-secondary)', marginTop: 4 }}>
                      {selected.reporter?.email} · {selected.reporter_role}
                    </div>
                  </div>
                  <div className="info-tile">
                    <div className="info-tile__label">Submitted</div>
                    <div className="info-tile__value">
                      {format(new Date(selected.created_at), 'MMM d, yyyy HH:mm')}
                    </div>
                  </div>
                  {selected.reported_user && (
                    <div className="info-tile">
                      <div className="info-tile__label">Reported user</div>
                      <div className="info-tile__value">{selected.reported_user.name}</div>
                      <div style={{ fontSize: 12, color: 'var(--text-secondary)', marginTop: 4 }}>
                        {selected.reported_user.email}
                      </div>
                    </div>
                  )}
                  {selected.workspaces && (
                    <div className="info-tile">
                      <div className="info-tile__label">Workspace</div>
                      <div className="info-tile__value">{selected.workspaces.name}</div>
                      <div style={{ fontSize: 12, color: 'var(--text-secondary)', marginTop: 4 }}>
                        {selected.workspaces.city}
                      </div>
                    </div>
                  )}
                  {selected.bookings && (
                    <div className="info-tile">
                      <div className="info-tile__label">Booking</div>
                      <div className="info-tile__value">{selected.bookings.workspace_name}</div>
                      <div style={{ fontSize: 12, color: 'var(--text-secondary)', marginTop: 4 }}>
                        Status: {selected.bookings.status}
                      </div>
                    </div>
                  )}
                </div>

                <div className="info-tile" style={{ marginBottom: 16 }}>
                  <div className="info-tile__label">Description</div>
                  <p style={{ margin: '6px 0 0', lineHeight: 1.6, whiteSpace: 'pre-wrap' }}>{selected.description}</p>
                </div>

                {Array.isArray(selected.evidence_urls) && selected.evidence_urls.length > 0 && (
                  <div style={{ marginBottom: 16 }}>
                    <div className="info-tile__label" style={{ marginBottom: 8 }}>Evidence</div>
                    <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                      {selected.evidence_urls.map((url, i) => (
                        <a
                          key={i}
                          href={url}
                          target="_blank"
                          rel="noreferrer"
                          className="btn btn--ghost btn--sm"
                        >
                          <ExternalLink size={14} /> Image {i + 1}
                        </a>
                      ))}
                    </div>
                  </div>
                )}

                <div style={{ marginBottom: 16 }}>
                  <div className="info-tile__label" style={{ marginBottom: 10 }}>Conversation</div>
                  {loadingFollowups ? (
                    <p style={{ color: 'var(--text-tertiary)', fontSize: 14 }}>Loading messages...</p>
                  ) : followupsLoadError ? (
                    <div className="info-tile" style={{ background: 'var(--warning-soft)', borderColor: '#fde68a' }}>
                      <p style={{ margin: 0, fontSize: 14, color: '#92400e' }}>{followupsLoadError}</p>
                    </div>
                  ) : followups.length === 0 ? (
                    <p style={{ color: 'var(--text-tertiary)', fontSize: 14, margin: 0 }}>No follow-up messages yet.</p>
                  ) : (
                    <div className="thread">
                      {followups.map((f) => (
                        <div
                          key={f.id}
                          className={`thread-bubble ${f.author_role === 'staff' ? 'thread-bubble--staff' : 'thread-bubble--reporter'}`}
                        >
                          <div className="thread-bubble__meta">
                            {f.author_role === 'staff' ? 'Staff' : 'Reporter'}
                            {f.author?.name ? ` · ${f.author.name}` : ''}
                            {' · '}
                            {format(new Date(f.created_at), 'MMM d, HH:mm')}
                          </div>
                          <div className="thread-bubble__text">{f.message}</div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                <Field label="Reply to reporter">
                  <textarea
                    className="textarea"
                    value={staffReply}
                    onChange={(e) => setStaffReply(e.target.value)}
                    placeholder={
                      followupsLoadError
                        ? 'Run migration 50 in Supabase before sending replies'
                        : 'Ask for more details or share an update...'
                    }
                    rows={2}
                    disabled={Boolean(followupsLoadError)}
                  />
                  <Btn
                    variant="primary"
                    size="sm"
                    onClick={sendStaffReply}
                    disabled={processing || !staffReply.trim() || Boolean(followupsLoadError)}
                  >
                    Send reply
                  </Btn>
                </Field>

                {!['resolved', 'dismissed'].includes(selected.status) && (
                  <>
                    <Field label="Resolution note" hint="Sent to reporter when you resolve or dismiss">
                      <textarea
                        className="textarea"
                        value={note}
                        onChange={(e) => setNote(e.target.value)}
                        placeholder="Explain your decision to the reporter..."
                        rows={3}
                      />
                    </Field>

                    {(selected.workspace_id || selected.reported_user) && (
                      <Field label="Enforcement action">
                        <select
                          className="select"
                          value={staffAction}
                          onChange={(e) => setStaffAction(e.target.value)}
                        >
                          <option value="none">No enforcement action</option>
                          {selected.reported_user && (
                            <option value="user_suspended">Suspend reported user</option>
                          )}
                          {selected.workspace_id && (
                            <option value="workspace_hidden">Hide workspace listing</option>
                          )}
                        </select>
                      </Field>
                    )}

                    <div className="action-row">
                      {selected.status === 'pending' && (
                        <Btn variant="secondary" icon={Eye} onClick={() => processReport('under_review')} disabled={processing}>
                          Under review
                        </Btn>
                      )}
                      <Btn variant="success" icon={Check} onClick={() => processReport('resolved')} disabled={processing}>
                        Resolve
                      </Btn>
                      <Btn variant="danger" icon={X} onClick={() => processReport('dismissed')} disabled={processing}>
                        Dismiss
                      </Btn>
                    </div>
                  </>
                )}

                {selected.resolution_note && ['resolved', 'dismissed'].includes(selected.status) && (
                  <div className="info-tile" style={{ marginTop: 16, background: 'var(--success-soft)', borderColor: '#a7f3d0' }}>
                    <div className="info-tile__label">Resolution note</div>
                    <p style={{ margin: '6px 0 0' }}>{selected.resolution_note}</p>
                  </div>
                )}
              </>
            )}
          </Panel>
        </div>
      )}
    </div>
  )
}

export default Reports
