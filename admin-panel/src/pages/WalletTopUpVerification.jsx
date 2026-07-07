import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { format } from 'date-fns'
import { Wallet, RefreshCw, Check, X, Eye } from 'lucide-react'
import Loading from '../components/Loading'
import EmptyState from '../components/EmptyState'
import QueryBanner from '../components/QueryBanner'
import { showSuccess, showError } from '../utils/toast'
import { fetchPlain, hydrateUserField, isSchemaError } from '../lib/staffQuery'

const FILTERS = ['pending', 'approved', 'rejected', 'all']

const WalletTopUpVerification = () => {
  const [requests, setRequests] = useState([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('pending')
  const [loadError, setLoadError] = useState('')
  const [selected, setSelected] = useState(null)
  const [rejectReason, setRejectReason] = useState('')
  const [processing, setProcessing] = useState(false)

  useEffect(() => {
    fetchPending()
  }, [filter])

  const fetchPending = async () => {
    try {
      setLoading(true)
      setLoadError('')

      const rows = await fetchPlain('wallet_topup_requests', {
        filter: filter !== 'all' ? (q) => q.eq('status', filter) : undefined,
        order: { column: 'created_at', ascending: false },
      })

      const data = await hydrateUserField(rows, { idKey: 'user_id', targetKey: 'user' })
      setRequests(data)
    } catch (e) {
      const msg = e?.message || String(e)
      if (isSchemaError(e, 'wallet_topup_requests')) {
        setLoadError('wallet_topup_requests table missing. Run supabase/28_wallet_topup_requests.sql and 29_wallet_topup_staff.sql in Supabase.')
      } else {
        setLoadError(msg)
      }
      setRequests([])
      showError(msg)
    } finally {
      setLoading(false)
    }
  }

  const handleVerify = async (approve) => {
    if (!selected) return
    setProcessing(true)
    try {
      const { error } = await supabase.rpc('staff_verify_topup_request', {
        p_request_id: selected.id,
        p_approve: approve,
        p_reason: approve ? null : (rejectReason.trim() || 'Receipt rejected'),
      })
      if (error) throw error
      showSuccess(approve ? 'Top-up approved — wallet credited' : 'Top-up request rejected')
      setSelected(null)
      setRejectReason('')
      fetchPending()
    } catch (e) {
      showError(e.message)
    } finally {
      setProcessing(false)
    }
  }

  if (loading) return <Loading message="Loading wallet top-ups..." />

  return (
    <div className="fade-in">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px', flexWrap: 'wrap', gap: '16px' }}>
        <div>
          <h1 style={{ fontSize: '32px', fontWeight: '800', marginBottom: '8px', color: 'var(--text-primary)' }}>
            Wallet Top-Up Verification
          </h1>
          <p style={{ color: '#64748b' }}>
            Users submit bank/EasyPaisa/JazzCash receipts here. Verify and credit their wallet.
          </p>
        </div>
        <button
          onClick={fetchPending}
          style={{ display: 'flex', alignItems: 'center', gap: '8px', padding: '12px 20px', background: '#6366f1', color: 'white', border: 'none', borderRadius: '10px', cursor: 'pointer', fontWeight: '600' }}
        >
          <RefreshCw size={18} /> Refresh
        </button>
      </div>

      <QueryBanner
        error={loadError}
        hint="After running migrations, refresh this page."
      />

      <div style={{ display: 'flex', gap: '8px', marginBottom: '24px', flexWrap: 'wrap' }}>
        {FILTERS.map((f) => (
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
      </div>

      {requests.length === 0 ? (
        <EmptyState
          icon={Wallet}
          title={loadError ? 'Top-ups unavailable' : 'No top-up requests'}
          message={
            loadError
              ? 'Fix the database error above, then refresh.'
              : filter === 'pending'
                ? 'No pending top-ups — try the All tab to see history.'
                : `No ${filter === 'all' ? '' : filter} top-up requests found.`
          }
        />
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: selected ? '1fr 1fr' : '1fr', gap: '24px' }}>
          <div style={{ display: 'grid', gap: '12px' }}>
            {requests.map((r) => (
              <div
                key={r.id}
                onClick={() => setSelected(r)}
                style={{
                  background: 'white', padding: '20px', borderRadius: '12px', cursor: 'pointer',
                  border: selected?.id === r.id ? '2px solid #6366f1' : '1px solid #e2e8f0',
                  boxShadow: '0 2px 12px rgba(0,0,0,0.06)',
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px', gap: 8 }}>
                  <strong style={{ color: '#1e293b' }}>{r.user?.name || 'User'}</strong>
                  <span style={{ color: '#10b981', fontWeight: '700' }}>PKR {parseFloat(r.amount).toLocaleString()}</span>
                </div>
                <div style={{ color: '#64748b', fontSize: '14px' }}>{r.user?.email || r.user_id}</div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '8px', fontSize: '12px' }}>
                  <span style={{
                    padding: '2px 8px', borderRadius: 12, fontWeight: 600, textTransform: 'capitalize',
                    background: r.status === 'pending' ? '#fef3c7' : r.status === 'approved' ? '#d1fae5' : '#fee2e2',
                    color: r.status === 'pending' ? '#b45309' : r.status === 'approved' ? '#047857' : '#b91c1c',
                  }}>
                    {r.status}
                  </span>
                  <span style={{ color: '#94a3b8' }}>{format(new Date(r.created_at), 'MMM dd, yyyy HH:mm')}</span>
                </div>
              </div>
            ))}
          </div>

          {selected && (
            <div style={{ background: 'white', padding: '24px', borderRadius: '16px', boxShadow: '0 4px 20px rgba(0,0,0,0.08)', position: 'sticky', top: '20px' }}>
              <h3 style={{ marginBottom: '16px', color: '#1e293b' }}>Review Top-Up</h3>
              <div style={{ marginBottom: '12px', color: '#334155' }}><strong>User:</strong> {selected.user?.name} ({selected.user?.email})</div>
              {selected.user?.phone && (
                <div style={{ marginBottom: '12px', color: '#334155' }}><strong>Phone:</strong> {selected.user.phone}</div>
              )}
              <div style={{ marginBottom: '12px', color: '#334155' }}><strong>Amount:</strong> PKR {parseFloat(selected.amount).toLocaleString()}</div>
              <div style={{ marginBottom: '12px', color: '#334155' }}><strong>Status:</strong> {selected.status}</div>
              {selected.transfer_reference && (
                <div style={{ marginBottom: '12px', color: '#334155' }}><strong>Reference:</strong> {selected.transfer_reference}</div>
              )}
              {selected.receipt_url && (
                <div style={{ marginBottom: '16px' }}>
                  <strong style={{ color: '#334155' }}>Receipt:</strong>
                  <div style={{ marginTop: '8px' }}>
                    <a href={selected.receipt_url} target="_blank" rel="noreferrer" style={{ display: 'inline-flex', alignItems: 'center', gap: '6px', color: '#6366f1' }}>
                      <Eye size={16} /> View receipt image
                    </a>
                    <img src={selected.receipt_url} alt="Receipt" style={{ width: '100%', maxHeight: '300px', objectFit: 'contain', marginTop: '12px', borderRadius: '8px', border: '1px solid #e2e8f0' }} />
                  </div>
                </div>
              )}
              {selected.status === 'pending' ? (
                <>
                  <textarea
                    placeholder="Rejection reason (if rejecting)"
                    value={rejectReason}
                    onChange={(e) => setRejectReason(e.target.value)}
                    style={{ width: '100%', minHeight: '80px', padding: '12px', borderRadius: '8px', border: '1px solid #e2e8f0', marginBottom: '16px', boxSizing: 'border-box' }}
                  />
                  <div style={{ display: 'flex', gap: '12px' }}>
                    <button
                      onClick={() => handleVerify(true)}
                      disabled={processing}
                      style={{ flex: 1, padding: '14px', background: '#10b981', color: 'white', border: 'none', borderRadius: '10px', cursor: 'pointer', fontWeight: '700', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}
                    >
                      <Check size={18} /> Approve & Credit
                    </button>
                    <button
                      onClick={() => handleVerify(false)}
                      disabled={processing}
                      style={{ flex: 1, padding: '14px', background: '#ef4444', color: 'white', border: 'none', borderRadius: '10px', cursor: 'pointer', fontWeight: '700', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}
                    >
                      <X size={18} /> Reject
                    </button>
                  </div>
                </>
              ) : (
                <p style={{ color: '#64748b', fontSize: 14 }}>This request was already {selected.status}.</p>
              )}
            </div>
          )}
        </div>
      )}
    </div>
  )
}

export default WalletTopUpVerification
