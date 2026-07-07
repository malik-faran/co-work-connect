import { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { format } from 'date-fns'
import { Inbox, RefreshCw, Check, Flag, ExternalLink } from 'lucide-react'
import Loading from '../components/Loading'
import {
  PageHeader,
  Panel,
  FilterTabs,
  Btn,
  EmptyPanel,
} from '../components/ui/PageShell'
import { showError } from '../utils/toast'

const FILTER_OPTIONS = [
  { value: 'unread', label: 'Unread' },
  { value: 'all', label: 'All' },
  { value: 'reports', label: 'Reports' },
]

const StaffInbox = ({ user }) => {
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('unread')

  useEffect(() => {
    if (user?.id) fetchInbox()
  }, [filter, user?.id])

  const fetchInbox = async () => {
    if (!user?.id) return
    try {
      setLoading(true)
      let query = supabase
        .from('notifications')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false })
        .limit(100)

      if (filter === 'unread') query = query.eq('is_read', false)
      if (filter === 'reports') {
        query = query.in('type', ['report_received', 'report_under_review', 'report_resolved', 'report_dismissed'])
      }

      const { data, error } = await query
      if (error) throw error
      setItems(data || [])
    } catch (e) {
      showError(e.message || 'Failed to load inbox')
    } finally {
      setLoading(false)
    }
  }

  const markRead = async (id) => {
    try {
      const { error } = await supabase
        .from('notifications')
        .update({ is_read: true })
        .eq('id', id)
        .eq('user_id', user.id)
      if (error) throw error
      setItems((prev) => prev.map((n) => (n.id === id ? { ...n, is_read: true } : n)))
    } catch (e) {
      showError(e.message)
    }
  }

  const markAllRead = async () => {
    try {
      const { error } = await supabase
        .from('notifications')
        .update({ is_read: true })
        .eq('user_id', user.id)
        .eq('is_read', false)
      if (error) throw error
      fetchInbox()
    } catch (e) {
      showError(e.message)
    }
  }

  const reportLink = (meta) => {
    const id = meta?.report_id
    return id ? `/reports` : null
  }

  if (loading) return <Loading message="Loading inbox..." />

  const unread = items.filter((n) => !n.is_read).length

  return (
    <div className="fade-in">
      <PageHeader
        title="Staff Inbox"
        subtitle="Alerts sent to you — new reports, follow-ups, and platform events."
        badge={unread > 0 ? `${unread} unread` : null}
        actions={
          <>
            <Btn variant="secondary" icon={RefreshCw} onClick={fetchInbox}>Refresh</Btn>
            {unread > 0 && (
              <Btn variant="ghost" icon={Check} onClick={markAllRead}>Mark all read</Btn>
            )}
          </>
        }
      />

      <FilterTabs options={FILTER_OPTIONS} value={filter} onChange={setFilter} />

      {items.length === 0 ? (
        <Panel>
          <EmptyPanel
            icon={Inbox}
            title="Inbox clear"
            message={filter === 'unread' ? 'No unread alerts.' : 'No notifications in this filter.'}
          />
        </Panel>
      ) : (
        <div style={{ display: 'grid', gap: 10 }}>
          {items.map((n) => {
            const meta = n.metadata || {}
            const link = reportLink(meta)
            return (
              <Panel key={n.id} className={!n.is_read ? '' : ''} style={{ opacity: n.is_read ? 0.85 : 1 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap' }}>
                  <div style={{ flex: 1, minWidth: 200 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
                      {!n.is_read && (
                        <span style={{ width: 8, height: 8, borderRadius: '50%', background: 'var(--primary)' }} />
                      )}
                      <strong style={{ fontSize: 15 }}>{n.title}</strong>
                      <span className="badge badge--primary" style={{ fontSize: 10 }}>{n.type}</span>
                    </div>
                    <p style={{ margin: 0, color: 'var(--text-secondary)', fontSize: 14, lineHeight: 1.5 }}>
                      {n.message}
                    </p>
                    <div style={{ fontSize: 12, color: 'var(--text-tertiary)', marginTop: 8 }}>
                      {format(new Date(n.created_at), 'MMM d, yyyy · HH:mm')}
                    </div>
                  </div>
                  <div style={{ display: 'flex', gap: 8, alignItems: 'flex-start' }}>
                    {!n.is_read && (
                      <Btn variant="ghost" size="sm" onClick={() => markRead(n.id)}>Mark read</Btn>
                    )}
                    {(link || n.type?.startsWith('report')) && (
                      <Link to="/reports" style={{ textDecoration: 'none' }}>
                        <Btn variant="secondary" size="sm" icon={Flag}>Open reports</Btn>
                      </Link>
                    )}
                    {meta?.objection && (
                      <span className="badge" style={{ background: 'var(--warning-soft)', color: 'var(--warning)' }}>
                        Follow-up
                      </span>
                    )}
                  </div>
                </div>
              </Panel>
            )
          })}
        </div>
      )}
    </div>
  )
}

export default StaffInbox
