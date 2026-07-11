import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { format } from 'date-fns'
import { Wallet, RefreshCw, Check, X } from 'lucide-react'
import Loading from '../components/Loading'
import EmptyState from '../components/EmptyState'
import QueryBanner from '../components/QueryBanner'
import { showSuccess, showError } from '../utils/toast'
import { fetchPlain, hydrateUserField, isSchemaError } from '../lib/staffQuery'

const WalletRefunds = () => {
  const [refunds, setRefunds] = useState([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('pending')
  const [note, setNote] = useState('')
  const [selected, setSelected] = useState(null)
  const [processing, setProcessing] = useState(false)
  const [loadError, setLoadError] = useState('')

  useEffect(() => {
    fetchRefunds()
  }, [filter])

  const fetchRefunds = async () => {
    try {
      setLoading(true)
      setLoadError('')

      const rows = await fetchPlain('refund_requests', {
        filter: filter !== 'all' ? (q) => q.eq('status', filter) : undefined,
        order: { column: 'created_at', ascending: false },
      })

      let data = await hydrateUserField(rows, { idKey: 'user_id', targetKey: 'requester' })

      const bookingIds = [...new Set(data.map((r) => r.booking_id).filter(Boolean))]
      if (bookingIds.length) {
        const { data: bookings, error: bErr } = await supabase
          .from('bookings')
          .select('id, workspace_name, total_price, status')
          .in('id', bookingIds)
        if (bErr) throw bErr
        const bookingMap = Object.fromEntries((bookings || []).map((b) => [b.id, b]))
        data = data.map((r) => ({ ...r, bookings: bookingMap[r.booking_id] || null }))
      }

      setRefunds(data)
    } catch (e) {
      const msg = e?.message || String(e)
      if (isSchemaError(e, 'refund_requests')) {
        setLoadError('refund_requests table missing. Run supabase/19_moderator_platform_wallet.sql in Supabase.')
      } else {
        setLoadError(msg.includes('Failed to fetch')
          ? 'Cannot reach Supabase — check connection.'
          : msg)
      }
      setRefunds([])
      showError(msg)
    } finally {
      setLoading(false)
    }
  }

  const approve = async (id) => {
    setProcessing(true)
    try {
      const { error } = await supabase.rpc('approve_refund_to_wallet', {
        p_refund_id: id,
        p_admin_note: note.trim() || null,
      })
      if (error) throw error
      showSuccess('Refund approved — amount credited to user wallet')
      setSelected(null)
      setNote('')
      fetchRefunds()
    } catch (e) {
      showError(e.message)
    } finally {
      setProcessing(false)
    }
  }

  const reject = async (id) => {
    const reason = note.trim()
    if (reason.length < 5) {
      showError('Please enter a rejection reason (at least 5 characters) — the user will see this in their notification.')
      return
    }
    setProcessing(true)
    try {
      const { error } = await supabase.rpc('reject_refund_request', {
        p_refund_id: id,
        p_admin_note: reason,
      })
      if (error) throw error
      showSuccess('Refund rejected')
      setSelected(null)
      setNote('')
      fetchRefunds()
    } catch (e) {
      showError(e.message)
    } finally {
      setProcessing(false)
    }
  }

  if (loading) return <Loading message="Loading refund requests..." />

  return (
    <div className="fade-in">
      <div style={{ marginBottom: '32px' }}>
        <h1 style={{ fontSize: '32px', fontWeight: '800', marginBottom: '8px', color: 'var(--text-primary)' }}>Wallet & Refunds</h1>
        <p style={{ color: '#64748b' }}>
          Approve cancellation refunds — amount goes to user&apos;s in-app wallet (Foodpanda style).
        </p>
      </div>

      <QueryBanner error={loadError} hint="Run migration 19, then refresh." />

      <div style={{ display: 'flex', gap: '8px', marginBottom: '24px', flexWrap: 'wrap' }}>
        {['pending', 'approved', 'rejected', 'all'].map((f) => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            style={{
              padding: '10px 16px', borderRadius: '8px', border: 'none', cursor: 'pointer',
              background: filter === f ? '#6366f1' : '#f1f5f9',
              color: filter === f ? 'white' : '#475569', fontWeight: '600', textTransform: 'capitalize',
            }}
          >
            {f}
          </button>
        ))}
        <button onClick={fetchRefunds} style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: '6px', padding: '10px 16px', border: '1px solid #e2e8f0', borderRadius: '8px', background: 'white', cursor: 'pointer' }}>
          <RefreshCw size={16} /> Refresh
        </button>
      </div>

      {refunds.length === 0 ? (
        <EmptyState icon={Wallet} title="No refund requests" message={`No ${filter === 'all' ? '' : filter} refunds found.`} />
      ) : (
        <div style={{ display: 'grid', gap: '12px' }}>
          {refunds.map((r) => (
            <div key={r.id} style={{
              background: 'white', padding: '20px', borderRadius: '12px',
              boxShadow: '0 2px 12px rgba(0,0,0,0.06)',
            }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', flexWrap: 'wrap', gap: '12px', marginBottom: '12px' }}>
                <div>
                  <strong>{r.requester?.name || r.users?.name || 'User'}</strong>
                  <div style={{ color: '#64748b', fontSize: '14px' }}>{r.requester?.email || r.users?.email}</div>
                  <div style={{ fontSize: '14px', marginTop: '4px' }}>{r.bookings?.workspace_name}</div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div style={{ fontSize: '20px', fontWeight: '800', color: '#10b981' }}>PKR {parseFloat(r.amount).toLocaleString()}</div>
                  <span style={{
                    fontSize: '12px', padding: '4px 10px', borderRadius: '20px', fontWeight: '600',
                    background: r.status === 'pending' ? '#fef3c7' : r.status === 'approved' ? '#d1fae5' : '#fee2e2',
                    color: r.status === 'pending' ? '#d97706' : r.status === 'approved' ? '#059669' : '#dc2626',
                  }}>
                    {r.status}
                  </span>
                </div>
              </div>
              {r.reason && <p style={{ color: '#64748b', fontSize: '14px', marginBottom: '8px' }}>Reason: {r.reason}</p>}
              <div style={{ fontSize: '12px', color: '#94a3b8' }}>{format(new Date(r.created_at), 'MMM dd, yyyy HH:mm')}</div>

              {r.status === 'pending' && (
                <div style={{ marginTop: '16px', paddingTop: '16px', borderTop: '1px solid #f1f5f9' }}>
                  {selected?.id === r.id ? (
                    <>
                      <textarea
                        placeholder="Note for user (required on reject — shown in their notification)"
                        value={note}
                        onChange={(e) => setNote(e.target.value)}
                        style={{ width: '100%', minHeight: '60px', padding: '10px', borderRadius: '8px', border: '1px solid #e2e8f0', marginBottom: '12px', boxSizing: 'border-box' }}
                      />
                      <div style={{ display: 'flex', gap: '10px' }}>
                        <button onClick={() => approve(r.id)} disabled={processing} style={{ flex: 1, padding: '12px', background: '#10b981', color: 'white', border: 'none', borderRadius: '8px', cursor: 'pointer', fontWeight: '600', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }}>
                          <Check size={16} /> Credit to Wallet
                        </button>
                        <button onClick={() => reject(r.id)} disabled={processing} style={{ flex: 1, padding: '12px', background: '#ef4444', color: 'white', border: 'none', borderRadius: '8px', cursor: 'pointer', fontWeight: '600', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }}>
                          <X size={16} /> Reject
                        </button>
                        <button onClick={() => { setSelected(null); setNote('') }} style={{ padding: '12px 16px', background: '#f1f5f9', border: 'none', borderRadius: '8px', cursor: 'pointer' }}>Cancel</button>
                      </div>
                    </>
                  ) : (
                    <button onClick={() => setSelected(r)} style={{ padding: '10px 16px', background: '#6366f1', color: 'white', border: 'none', borderRadius: '8px', cursor: 'pointer', fontWeight: '600' }}>
                      Process Refund
                    </button>
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

export default WalletRefunds
