import { useEffect, useState } from 'react'
import { paymentService } from '../../services/paymentService'
import { useAuth } from '../../context/AuthContext'
import { Loading, EmptyState, StatusBadge } from '../../components/common'
import { currency } from '../../lib/constants'
import { fmtDateTime } from '../../lib/helpers'

export default function PaymentHistory() {
  const { userId, isOwner } = useAuth()
  const [payments, setPayments] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const load = isOwner ? paymentService.getOwnerReceived(userId) : paymentService.getUserPayments(userId)
    load.then(setPayments).catch(console.error).finally(() => setLoading(false))
  }, [userId, isOwner])

  const totalEarned = payments.filter((p) => p.status === 'completed').reduce((s, p) => s + Number(p.amount || 0), 0)

  if (loading) return <Loading message="Loading payments..." />

  return (
    <div className="container-app" style={{ maxWidth: 820 }}>
      <h3 className="fw-bold mb-3">{isOwner ? 'Payments Received' : 'Payment History'}</h3>

      <div className="card-clean p-4 mb-4" style={{ background: 'var(--success-gradient)', color: '#fff' }}>
        <div className="small" style={{ opacity: 0.9 }}>{isOwner ? 'Total earnings (verified)' : 'Total paid'}</div>
        <div className="fw-bold fs-2 text-white">{currency(totalEarned)}</div>
      </div>

      {payments.length === 0 ? (
        <EmptyState icon="bi-receipt" title="No payments yet" />
      ) : (
        <div className="d-flex flex-column gap-2">
          {payments.map((p) => (
            <div className="card-clean p-3 d-flex justify-content-between align-items-center" key={p.id}>
              <div>
                <div className="fw-semibold">{p.bookings?.workspace_name || 'Booking'}</div>
                <div className="small text-secondary">{fmtDateTime(p.created_at)} · {p.payment_method}</div>
              </div>
              <div className="text-end">
                <div className="fw-bold">{currency(p.amount)}</div>
                <StatusBadge status={p.receipt_status || p.status} />
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
