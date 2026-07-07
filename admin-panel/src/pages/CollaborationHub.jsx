import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { format } from 'date-fns'
import { Briefcase, RefreshCw, Check, RotateCcw } from 'lucide-react'
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

const PAYMENT_STATUS = {
  held: { bg: '#fef3c7', color: '#b45309' },
  released: { bg: '#d1fae5', color: '#047857' },
  refunded: { bg: '#fee2e2', color: '#b91c1c' },
  pending: { bg: '#f1f5f9', color: '#64748b' },
  failed: { bg: '#fee2e2', color: '#991b1b' },
}

const FILTER_OPTIONS = [
  { value: 'held', label: 'Held (disputes)' },
  { value: 'all', label: 'All payments' },
  { value: 'released', label: 'Released' },
  { value: 'refunded', label: 'Refunded' },
]

const CollaborationHub = () => {
  const [payments, setPayments] = useState([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('held')
  const [selected, setSelected] = useState(null)
  const [reason, setReason] = useState('')
  const [processing, setProcessing] = useState(false)
  const [milestones, setMilestones] = useState([])

  useEffect(() => {
    fetchPayments()
  }, [filter])

  const fetchPayments = async () => {
    try {
      setLoading(true)
      let query = supabase
        .from('collaboration_payments')
        .select(`
          *,
          collaborations(title, status),
          milestone:collaboration_milestones(title, status, submission_note),
          payer:users!collaboration_payments_payer_id_fkey(name, email),
          payee:users!collaboration_payments_payee_id_fkey(name, email)
        `)
        .order('created_at', { ascending: false })
        .limit(80)

      if (filter !== 'all') query = query.eq('status', filter)

      let { data, error } = await query

      if (error) {
        const plain = await supabase
          .from('collaboration_payments')
          .select('*')
          .order('created_at', { ascending: false })
          .limit(80)
        if (plain.error) {
          if (plain.error.code === '42P01' || plain.error.message?.includes('collaboration_payments')) {
            throw new Error('Run supabase/49_admin_panel_enhancements.sql in Supabase SQL Editor.')
          }
          throw plain.error
        }
        let rows = plain.data || []
        if (filter !== 'all') rows = rows.filter((r) => r.status === filter)
        data = rows
      }

      setPayments(data || [])
      if (selected && !(data || []).some((p) => p.id === selected.id)) {
        setSelected(null)
      }
    } catch (e) {
      showError(e.message || String(e))
    } finally {
      setLoading(false)
    }
  }

  const loadMilestones = async (collabId) => {
    const { data } = await supabase
      .from('collaboration_milestones')
      .select('id, title, status, amount, due_date, submission_note')
      .eq('collaboration_id', collabId)
      .order('sort_order', { ascending: true })
    setMilestones(data || [])
  }

  const openPayment = (p) => {
    setSelected(p)
    setReason('')
    if (p.collaboration_id) loadMilestones(p.collaboration_id)
  }

  const runAction = async (action) => {
    if (!selected) return
    if (!reason.trim() || reason.trim().length < 5) {
      showError('Provide a reason (min 5 characters)')
      return
    }
    setProcessing(true)
    try {
      const rpc = action === 'release'
        ? 'staff_force_release_collaboration_payment'
        : 'staff_refund_held_collaboration_payment'
      const { error } = await supabase.rpc(rpc, {
        p_payment_id: selected.id,
        p_reason: reason.trim(),
      })
      if (error) throw error
      showSuccess(action === 'release' ? 'Payment released to payee' : 'Payment refunded to payer')
      setSelected(null)
      setReason('')
      fetchPayments()
    } catch (e) {
      showError(e.message)
    } finally {
      setProcessing(false)
    }
  }

  const heldCount = payments.filter((p) => p.status === 'held').length

  if (loading) return <Loading message="Loading collaboration payments..." />

  return (
    <div className="fade-in">
      <PageHeader
        title="Collaboration Hub"
        subtitle="Review escrow milestone payments, resolve disputes, and force-release or refund held funds."
        badge={filter === 'held' && heldCount > 0 ? `${heldCount} held` : null}
        actions={
          <Btn variant="secondary" icon={RefreshCw} onClick={fetchPayments}>Refresh</Btn>
        }
      />

      <FilterTabs options={FILTER_OPTIONS} value={filter} onChange={setFilter} />

      {payments.length === 0 ? (
        <Panel>
          <EmptyPanel
            icon={Briefcase}
            title="No payments"
            message={filter === 'held' ? 'No held escrow payments — nothing to dispute.' : 'No collaboration payments in this filter.'}
          />
        </Panel>
      ) : (
        <div className="reports-layout">
          <Panel padding={false}>
            <div style={{ padding: '16px', borderBottom: '1px solid var(--border)' }}>
              <strong>{payments.length} payment{payments.length !== 1 ? 's' : ''}</strong>
            </div>
            <div className="report-list" style={{ padding: 12 }}>
              {payments.map((p) => (
                <button
                  key={p.id}
                  type="button"
                  className={`report-card ${selected?.id === p.id ? 'is-selected' : ''}`}
                  onClick={() => openPayment(p)}
                  style={{ width: '100%', textAlign: 'left' }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, marginBottom: 6 }}>
                    <strong style={{ fontSize: 14 }}>
                      PKR {Number(p.amount).toLocaleString()}
                    </strong>
                    <StatusBadge status={p.status} map={PAYMENT_STATUS} />
                  </div>
                  <div style={{ fontSize: 13, color: 'var(--text-secondary)' }}>
                    {p.milestone?.title || p.collaborations?.title || 'Milestone'}
                  </div>
                  <div style={{ fontSize: 12, color: 'var(--text-tertiary)', marginTop: 4 }}>
                    {p.payer?.name || 'Payer'} → {p.payee?.name || 'Payee'}
                  </div>
                </button>
              ))}
            </div>
          </Panel>

          <Panel>
            {!selected ? (
              <EmptyPanel
                icon={Briefcase}
                title="Select a payment"
                message="Choose a held payment to review milestone context and take action."
              />
            ) : (
              <>
                <h2 style={{ fontSize: 18, fontWeight: 800, marginBottom: 12 }}>
                  PKR {Number(selected.amount).toLocaleString()}
                  {' '}
                  <StatusBadge status={selected.status} map={PAYMENT_STATUS} />
                </h2>

                <div className="report-detail-grid" style={{ marginBottom: 16 }}>
                  <div className="info-tile">
                    <div className="info-tile__label">Project</div>
                    <div className="info-tile__value">{selected.collaborations?.title || '—'}</div>
                  </div>
                  <div className="info-tile">
                    <div className="info-tile__label">Milestone</div>
                    <div className="info-tile__value">{selected.milestone?.title || '—'}</div>
                    <div style={{ fontSize: 12, color: 'var(--text-secondary)', marginTop: 4 }}>
                      Status: {selected.milestone?.status || '—'}
                    </div>
                  </div>
                  <div className="info-tile">
                    <div className="info-tile__label">Payer</div>
                    <div className="info-tile__value">{selected.payer?.name || '—'}</div>
                    <div style={{ fontSize: 12, color: 'var(--text-secondary)' }}>{selected.payer?.email}</div>
                  </div>
                  <div className="info-tile">
                    <div className="info-tile__label">Payee</div>
                    <div className="info-tile__value">{selected.payee?.name || '—'}</div>
                    <div style={{ fontSize: 12, color: 'var(--text-secondary)' }}>{selected.payee?.email}</div>
                  </div>
                </div>

                {selected.milestone?.submission_note && (
                  <div className="info-tile" style={{ marginBottom: 16 }}>
                    <div className="info-tile__label">Submission note</div>
                    <p style={{ margin: '6px 0 0', whiteSpace: 'pre-wrap' }}>{selected.milestone.submission_note}</p>
                  </div>
                )}

                {milestones.length > 0 && (
                  <div style={{ marginBottom: 16 }}>
                    <div className="info-tile__label" style={{ marginBottom: 8 }}>All milestones</div>
                    <div style={{ display: 'grid', gap: 6 }}>
                      {milestones.map((m) => (
                        <div key={m.id} className="info-tile" style={{ padding: 10 }}>
                          <strong style={{ fontSize: 13 }}>{m.title}</strong>
                          <span style={{ marginLeft: 8, fontSize: 12, color: 'var(--text-tertiary)' }}>{m.status}</span>
                          {m.amount != null && (
                            <span style={{ marginLeft: 8, fontSize: 12 }}>PKR {Number(m.amount).toLocaleString()}</span>
                          )}
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {selected.status === 'held' && (
                  <>
                    <Field label="Staff reason" hint="Required for audit log and user notification">
                      <textarea
                        className="textarea"
                        rows={3}
                        value={reason}
                        onChange={(e) => setReason(e.target.value)}
                        placeholder="Why are you releasing or refunding this payment?"
                      />
                    </Field>
                    <div className="action-row">
                      <Btn variant="success" icon={Check} disabled={processing} onClick={() => runAction('release')}>
                        Release to payee
                      </Btn>
                      <Btn variant="danger" icon={RotateCcw} disabled={processing} onClick={() => runAction('refund')}>
                        Refund to payer
                      </Btn>
                    </div>
                  </>
                )}

                <div style={{ fontSize: 12, color: 'var(--text-tertiary)', marginTop: 16 }}>
                  Created {format(new Date(selected.created_at), 'MMM d, yyyy HH:mm')}
                  {selected.released_at && ` · Updated ${format(new Date(selected.released_at), 'MMM d, yyyy HH:mm')}`}
                </div>
              </>
            )}
          </Panel>
        </div>
      )}
    </div>
  )
}

export default CollaborationHub
