import { useState, useEffect } from 'react'
import { useSearchParams } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { isAdmin } from '../lib/permissions'
import { History, RefreshCw, Filter } from 'lucide-react'
import { format } from 'date-fns'
import Loading from '../components/Loading'
import EmptyState from '../components/EmptyState'
import { showError } from '../utils/toast'

const ACTION_LABELS = {
  moderator_created: 'Moderator Registered',
  moderator_promoted: 'Promoted to Moderator',
  moderator_demoted: 'Moderator Removed',
  owner_approved: 'Owner Approved',
  owner_rejected: 'Owner Rejected',
  workspace_approved: 'Workspace Approved',
  workspace_rejected: 'Workspace Rejected',
  payment_approved: 'Payment Approved',
  payment_rejected: 'Payment Rejected',
  refund_approved: 'Refund Approved',
  refund_rejected: 'Refund Rejected',
  notification_deleted: 'Notification Deleted',
  notification_marked_read: 'Notification Marked Read',
  platform_account_deleted: 'Platform Account Deleted',
  report_under_review: 'Report Under Review',
  report_resolved: 'Report Resolved',
  report_dismissed: 'Report Dismissed',
  owner_payout_approved: 'Owner Payout Approved',
  owner_payout_rejected: 'Owner Payout Rejected',
}

const ModeratorActivity = ({ user }) => {
  const [searchParams] = useSearchParams()
  const [logs, setLogs] = useState([])
  const [staff, setStaff] = useState([])
  const [loading, setLoading] = useState(true)
  const [filterActor, setFilterActor] = useState(searchParams.get('actor') || 'all')
  const [filterAction, setFilterAction] = useState('all')

  useEffect(() => {
    if (isAdmin(user?.role)) {
      fetchData()
    } else {
      setLoading(false)
    }
  }, [user])

  const fetchData = async () => {
    try {
      setLoading(true)
      const [logsRes, staffRes] = await Promise.all([
        supabase
          .from('staff_audit_log')
          .select('*')
          .order('created_at', { ascending: false })
          .limit(200),
        supabase
          .from('users')
          .select('id, name, email, role')
          .in('role', ['moderator', 'admin'])
          .order('name'),
      ])

      if (logsRes.error) throw logsRes.error
      const staffList = staffRes.data || []
      const staffMap = Object.fromEntries(staffList.map((s) => [s.id, s]))
      setLogs((logsRes.data || []).map((log) => ({
        ...log,
        actor: staffMap[log.actor_id] || null,
      })))
      setStaff(staffList)
    } catch (e) {
      showError(e.message)
    } finally {
      setLoading(false)
    }
  }

  const filtered = logs.filter((log) => {
    if (filterActor !== 'all' && log.actor_id !== filterActor) return false
    if (filterAction !== 'all' && log.action !== filterAction) return false
    return true
  })

  const uniqueActions = [...new Set(logs.map((l) => l.action))]

  if (!isAdmin(user?.role)) {
    return <EmptyState icon={History} title="Admin Only" message="Only admins can view activity history." />
  }

  if (loading) return <Loading message="Loading activity history..." />

  return (
    <div className="fade-in">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px', flexWrap: 'wrap', gap: '16px' }}>
        <div>
          <h1 style={{ fontSize: '32px', fontWeight: '800', marginBottom: '8px' }}>Staff Activity History</h1>
          <p style={{ color: '#64748b' }}>
            Track what each moderator and admin changed on the platform.
          </p>
        </div>
        <button onClick={fetchData} style={{ display: 'flex', alignItems: 'center', gap: '8px', padding: '12px 20px', background: '#6366f1', color: 'white', border: 'none', borderRadius: '10px', cursor: 'pointer', fontWeight: '600' }}>
          <RefreshCw size={18} /> Refresh
        </button>
      </div>

      <div style={{
        background: 'white', padding: '20px', borderRadius: '12px', marginBottom: '24px',
        display: 'flex', gap: '16px', flexWrap: 'wrap', alignItems: 'center',
        boxShadow: '0 2px 12px rgba(0,0,0,0.06)',
      }}>
        <Filter size={18} color="#64748b" />
        <select value={filterActor} onChange={(e) => setFilterActor(e.target.value)} style={{ padding: '10px 14px', borderRadius: '8px', border: '1px solid #e2e8f0', minWidth: '180px' }}>
          <option value="all">All staff</option>
          {staff.map((m) => (
            <option key={m.id} value={m.id}>{m.name} ({m.email})</option>
          ))}
        </select>
        <select value={filterAction} onChange={(e) => setFilterAction(e.target.value)} style={{ padding: '10px 14px', borderRadius: '8px', border: '1px solid #e2e8f0', minWidth: '180px' }}>
          <option value="all">All actions</option>
          {uniqueActions.map((a) => (
            <option key={a} value={a}>{ACTION_LABELS[a] || a}</option>
          ))}
        </select>
        <span style={{ color: '#64748b', fontSize: '14px' }}>{filtered.length} entries</span>
      </div>

      {filtered.length === 0 ? (
        <EmptyState icon={History} title="No activity yet" message="Actions by moderators will appear here." />
      ) : (
        <div style={{ display: 'grid', gap: '10px' }}>
          {filtered.map((log) => (
            <div key={log.id} style={{
              background: 'white', padding: '18px 20px', borderRadius: '12px',
              boxShadow: '0 2px 12px rgba(0,0,0,0.05)',
              borderLeft: `4px solid ${log.actor_role === 'admin' ? '#8b5cf6' : '#3b82f6'}`,
            }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', flexWrap: 'wrap', gap: '8px', marginBottom: '6px' }}>
                <div>
                  <span style={{
                    fontSize: '11px', fontWeight: '700', textTransform: 'uppercase',
                    padding: '3px 8px', borderRadius: '6px',
                    background: log.actor_role === 'admin' ? '#ede9fe' : '#dbeafe',
                    color: log.actor_role === 'admin' ? '#7c3aed' : '#2563eb',
                    marginRight: '8px',
                  }}>
                    {ACTION_LABELS[log.action] || log.action}
                  </span>
                  <strong>{log.actor?.name || 'Unknown'}</strong>
                  <span style={{ color: '#94a3b8', fontSize: '13px' }}> · {log.actor?.email}</span>
                </div>
                <span style={{ color: '#94a3b8', fontSize: '12px' }}>
                  {format(new Date(log.created_at), 'MMM dd, yyyy · HH:mm')}
                </span>
              </div>
              <p style={{ margin: '4px 0 0', color: '#475569', fontSize: '14px' }}>{log.summary}</p>
              {log.entity_type && (
                <p style={{ margin: '4px 0 0', fontSize: '12px', color: '#94a3b8' }}>
                  {log.entity_type}{log.entity_id ? ` · ${log.entity_id.slice(0, 8)}…` : ''}
                </p>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

export default ModeratorActivity
