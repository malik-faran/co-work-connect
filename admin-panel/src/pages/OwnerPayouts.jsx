import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { format } from 'date-fns'
import { Banknote, RefreshCw, Check, X } from 'lucide-react'
import Loading from '../components/Loading'
import EmptyState from '../components/EmptyState'
import { showSuccess, showError } from '../utils/toast'

const OwnerPayouts = () => {
  const [payouts, setPayouts] = useState([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('pending')
  const [note, setNote] = useState('')
  const [selected, setSelected] = useState(null)
  const [processing, setProcessing] = useState(false)

  useEffect(() => {
    fetchPayouts()
  }, [filter])

  const fetchPayouts = async () => {
    try {
      setLoading(true)

      let query = supabase
        .from('owner_payout_requests')
        .select(`
          *,
          owner:users!owner_payout_requests_owner_id_fkey(name, email),
          owner_payment_accounts(account_type, account_title, account_number, bank_name)
        `)
        .order('created_at', { ascending: false })

      if (filter !== 'all') query = query.eq('status', filter)

      let { data, error } = await query

      if (error) {
        const plain = await supabase
          .from('owner_payout_requests')
          .select('*')
          .order('created_at', { ascending: false })

        if (plain.error) {
          if (plain.error.message?.includes('owner_payout') || plain.error.code === '42P01') {
            throw new Error('owner_payout_requests missing. Run supabase/23_owner_wallet.sql')
          }
          throw plain.error
        }

        let rows = plain.data || []
        if (filter !== 'all') rows = rows.filter((r) => r.status === filter)

        const ownerIds = [...new Set(rows.map((r) => r.owner_id).filter(Boolean))]
        const accountIds = [...new Set(rows.map((r) => r.owner_account_id).filter(Boolean))]

        const [{ data: owners }, { data: accounts }] = await Promise.all([
          ownerIds.length
            ? supabase.from('users').select('id, name, email').in('id', ownerIds)
            : Promise.resolve({ data: [] }),
          accountIds.length
            ? supabase.from('owner_payment_accounts').select('*').in('id', accountIds)
            : Promise.resolve({ data: [] }),
        ])

        const ownerMap = Object.fromEntries((owners || []).map((o) => [o.id, o]))
        const accountMap = Object.fromEntries((accounts || []).map((a) => [a.id, a]))

        data = rows.map((r) => ({
          ...r,
          owner: ownerMap[r.owner_id] || null,
          owner_payment_accounts: accountMap[r.owner_account_id] || null,
        }))
        error = null
      }

      if (error) throw error
      setPayouts(data || [])
    } catch (e) {
      showError(e?.message || String(e))
    } finally {
      setLoading(false)
    }
  }

  const process = async (approve) => {
    if (!selected) return
    setProcessing(true)
    try {
      const { error } = await supabase.rpc('process_owner_payout', {
        p_payout_id: selected.id,
        p_approve: approve,
        p_note: note.trim() || null,
      })
      if (error) throw error
      showSuccess(approve ? 'Payout approved — transfer to owner account manually' : 'Payout rejected')
      setSelected(null)
      setNote('')
      fetchPayouts()
    } catch (e) {
      showError(e.message)
    } finally {
      setProcessing(false)
    }
  }

  const accountLabel = (acc) => {
    if (!acc) return '—'
    const type = acc.account_type === 'bank' ? (acc.bank_name || 'Bank') : acc.account_type
    return `${type} · ${acc.account_title} · ${acc.account_number}`
  }

  if (loading) return <Loading message="Loading owner payouts..." />

  return (
    <div className="fade-in">
      <div style={{ marginBottom: '32px' }}>
        <h1 style={{ fontSize: '32px', fontWeight: '800', marginBottom: '8px' }}>Owner Payouts</h1>
        <p style={{ color: '#64748b' }}>
          Owners withdraw wallet earnings to their bank / JazzCash / EasyPaisa. Approve after you send the transfer.
        </p>
      </div>

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
        <button
          onClick={fetchPayouts}
          style={{
            marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: '6px',
            padding: '10px 16px', border: '1px solid #e2e8f0', borderRadius: '8px',
            background: 'white', cursor: 'pointer',
          }}
        >
          <RefreshCw size={16} /> Refresh
        </button>
      </div>

      {payouts.length === 0 ? (
        <EmptyState icon={Banknote} title="No payout requests" message={`No ${filter === 'all' ? '' : filter} payouts.`} />
      ) : (
        <div style={{ display: 'grid', gap: '12px' }}>
          {payouts.map((p) => (
            <div
              key={p.id}
              onClick={() => { setSelected(p); setNote('') }}
              style={{
                background: 'white', padding: '20px', borderRadius: '12px',
                boxShadow: '0 2px 12px rgba(0,0,0,0.06)', cursor: 'pointer',
              }}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', flexWrap: 'wrap', gap: '12px' }}>
                <div>
                  <strong style={{ fontSize: '18px' }}>PKR {Number(p.amount).toLocaleString()}</strong>
                  <div style={{ color: '#64748b', fontSize: '14px', marginTop: '4px' }}>
                    {p.owner?.name} ({p.owner?.email})
                  </div>
                  <div style={{ fontSize: '13px', marginTop: '6px', color: '#475569' }}>
                    {accountLabel(p.owner_payment_accounts)}
                  </div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <span style={{
                    fontSize: '12px', padding: '4px 10px', borderRadius: '6px', fontWeight: '600',
                    background: p.status === 'pending' ? '#fef3c7' : p.status === 'approved' ? '#d1fae5' : '#f1f5f9',
                    color: p.status === 'pending' ? '#b45309' : p.status === 'approved' ? '#047857' : '#64748b',
                  }}>
                    {p.status}
                  </span>
                  <div style={{ fontSize: '12px', color: '#94a3b8', marginTop: '8px' }}>
                    {format(new Date(p.created_at), 'MMM d, yyyy HH:mm')}
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {selected && selected.status === 'pending' && (
        <div style={{
          position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: '16px',
        }}>
          <div style={{
            background: 'white', borderRadius: '16px', maxWidth: '520px', width: '100%', padding: '28px',
          }}>
            <h2 style={{ fontSize: '20px', fontWeight: '700', marginBottom: '12px' }}>
              Payout PKR {Number(selected.amount).toLocaleString()}
            </h2>
            <p style={{ color: '#64748b', marginBottom: '16px' }}>
              Send money to: <strong>{accountLabel(selected.owner_payment_accounts)}</strong>
            </p>
            <textarea
              value={note}
              onChange={(e) => setNote(e.target.value)}
              placeholder="Note to owner (optional)"
              rows={3}
              style={{
                width: '100%', padding: '12px', borderRadius: '8px',
                border: '1px solid #e2e8f0', marginBottom: '16px', resize: 'vertical',
              }}
            />
            <p style={{ fontSize: '13px', color: '#94a3b8', marginBottom: '16px' }}>
              Approve only after you have transferred funds to the owner&apos;s account. Wallet will be debited automatically.
            </p>
            <div style={{ display: 'flex', gap: '8px' }}>
              <button
                onClick={() => process(true)}
                disabled={processing}
                style={{
                  flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px',
                  padding: '12px', borderRadius: '8px', border: 'none', background: '#10b981',
                  color: 'white', cursor: 'pointer', fontWeight: '600',
                }}
              >
                <Check size={16} /> Approve (sent)
              </button>
              <button
                onClick={() => process(false)}
                disabled={processing}
                style={{
                  flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px',
                  padding: '12px', borderRadius: '8px', border: 'none', background: '#ef4444',
                  color: 'white', cursor: 'pointer', fontWeight: '600',
                }}
              >
                <X size={16} /> Reject
              </button>
            </div>
            <button
              onClick={() => setSelected(null)}
              style={{
                marginTop: '12px', width: '100%', padding: '10px', borderRadius: '8px',
                border: '1px solid #e2e8f0', background: 'white', cursor: 'pointer',
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

export default OwnerPayouts
