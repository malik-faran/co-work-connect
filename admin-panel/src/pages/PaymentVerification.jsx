import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { format } from 'date-fns'
import { ClipboardCheck, RefreshCw, Check, X, Eye } from 'lucide-react'
import Loading from '../components/Loading'
import EmptyState from '../components/EmptyState'
import { showSuccess, showError } from '../utils/toast'

const PaymentVerification = () => {
  const [payments, setPayments] = useState([])
  const [loading, setLoading] = useState(true)
  const [selected, setSelected] = useState(null)
  const [rejectReason, setRejectReason] = useState('')
  const [processing, setProcessing] = useState(false)

  useEffect(() => {
    fetchPending()
  }, [])

  const fetchPending = async () => {
    try {
      setLoading(true)
      let query = supabase
        .from('payments')
        .select(`
          *,
          bookings(id, workspace_name, total_price, start_date, end_date, status),
          payer:users!payments_user_id_fkey(name, email, phone)
        `)
        .eq('receipt_status', 'awaiting_verification')
        .order('created_at', { ascending: false })

      let { data, error } = await query.eq('payee_type', 'platform')

      if (error?.message?.includes('payee_type')) {
        const fallback = await supabase
          .from('payments')
          .select(`
            *,
            bookings(id, workspace_name, total_price, start_date, end_date, status),
            payer:users!payments_user_id_fkey(name, email, phone)
          `)
          .eq('receipt_status', 'awaiting_verification')
          .order('created_at', { ascending: false })
        data = fallback.data
        error = fallback.error
      }

      if (error?.message?.includes('more than one relationship')) {
        const plain = await supabase
          .from('payments')
          .select('*, bookings(id, workspace_name, total_price, start_date, end_date, status)')
          .eq('receipt_status', 'awaiting_verification')
          .order('created_at', { ascending: false })
        if (!plain.error && plain.data?.length) {
          const userIds = [...new Set(plain.data.map((p) => p.user_id).filter(Boolean))]
          const { data: userRows } = await supabase
            .from('users')
            .select('id, name, email, phone')
            .in('id', userIds)
          const userMap = Object.fromEntries((userRows || []).map((u) => [u.id, u]))
          data = plain.data.map((p) => ({ ...p, payer: userMap[p.user_id] || null }))
          error = null
        } else {
          data = plain.data
          error = plain.error
        }
      }

      if (error) throw error
      setPayments(data || [])
    } catch (e) {
      showError(e.message)
    } finally {
      setLoading(false)
    }
  }

  const handleVerify = async (approve) => {
    if (!selected) return
    setProcessing(true)
    try {
      const { error } = await supabase.rpc('staff_verify_platform_payment', {
        p_payment_id: selected.id,
        p_approve: approve,
        p_reason: approve ? null : (rejectReason.trim() || 'Receipt rejected'),
      })
      if (error) throw error
      showSuccess(approve ? 'Payment approved — booking confirmed & owner notified' : 'Receipt rejected')
      setSelected(null)
      setRejectReason('')
      fetchPending()
    } catch (e) {
      showError(e.message)
    } finally {
      setProcessing(false)
    }
  }

  if (loading) return <Loading message="Loading pending payments..." />

  return (
    <div className="fade-in">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px', flexWrap: 'wrap', gap: '16px' }}>
        <div>
          <h1 style={{ fontSize: '32px', fontWeight: '800', marginBottom: '8px' }}>Payment Verification</h1>
          <p style={{ color: '#64748b' }}>
            Users pay to CWC platform account. Verify receipts here — owner gets notified on approval.
          </p>
        </div>
        <button onClick={fetchPending} style={{ display: 'flex', alignItems: 'center', gap: '8px', padding: '12px 20px', background: '#6366f1', color: 'white', border: 'none', borderRadius: '10px', cursor: 'pointer', fontWeight: '600' }}>
          <RefreshCw size={18} /> Refresh
        </button>
      </div>

      {payments.length === 0 ? (
        <EmptyState icon={ClipboardCheck} title="No pending receipts" message="All platform payments are verified." />
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: selected ? '1fr 1fr' : '1fr', gap: '24px' }}>
          <div style={{ display: 'grid', gap: '12px' }}>
            {payments.map((p) => (
              <div
                key={p.id}
                onClick={() => setSelected(p)}
                style={{
                  background: 'white', padding: '20px', borderRadius: '12px', cursor: 'pointer',
                  border: selected?.id === p.id ? '2px solid #6366f1' : '1px solid #e2e8f0',
                  boxShadow: '0 2px 12px rgba(0,0,0,0.06)',
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
                  <strong>{p.payer?.name || 'User'}</strong>
                  <span style={{ color: '#10b981', fontWeight: '700' }}>PKR {parseFloat(p.amount).toLocaleString()}</span>
                </div>
                <div style={{ color: '#64748b', fontSize: '14px' }}>{p.bookings?.workspace_name}</div>
                <div style={{ color: '#94a3b8', fontSize: '12px', marginTop: '4px' }}>
                  {format(new Date(p.created_at), 'MMM dd, yyyy HH:mm')}
                </div>
              </div>
            ))}
          </div>

          {selected && (
            <div style={{ background: 'white', padding: '24px', borderRadius: '16px', boxShadow: '0 4px 20px rgba(0,0,0,0.08)', position: 'sticky', top: '20px' }}>
              <h3 style={{ marginBottom: '16px' }}>Review Payment</h3>
              <div style={{ marginBottom: '12px' }}><strong>User:</strong> {selected.payer?.name} ({selected.payer?.email})</div>
              <div style={{ marginBottom: '12px' }}><strong>Workspace:</strong> {selected.bookings?.workspace_name}</div>
              <div style={{ marginBottom: '12px' }}><strong>Amount:</strong> PKR {parseFloat(selected.amount).toLocaleString()}</div>
              {selected.transfer_reference && (
                <div style={{ marginBottom: '12px' }}><strong>Reference:</strong> {selected.transfer_reference}</div>
              )}
              {selected.receipt_url && (
                <div style={{ marginBottom: '16px' }}>
                  <strong>Receipt:</strong>
                  <div style={{ marginTop: '8px' }}>
                    <a href={selected.receipt_url} target="_blank" rel="noreferrer" style={{ display: 'inline-flex', alignItems: 'center', gap: '6px', color: '#6366f1' }}>
                      <Eye size={16} /> View receipt image
                    </a>
                    <img src={selected.receipt_url} alt="Receipt" style={{ width: '100%', maxHeight: '300px', objectFit: 'contain', marginTop: '12px', borderRadius: '8px', border: '1px solid #e2e8f0' }} />
                  </div>
                </div>
              )}
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
                  <Check size={18} /> Approve
                </button>
                <button
                  onClick={() => handleVerify(false)}
                  disabled={processing}
                  style={{ flex: 1, padding: '14px', background: '#ef4444', color: 'white', border: 'none', borderRadius: '10px', cursor: 'pointer', fontWeight: '700', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}
                >
                  <X size={18} /> Reject
                </button>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  )
}

export default PaymentVerification
