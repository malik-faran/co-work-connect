import { useEffect, useState } from 'react'
import { bookingService } from '../../services/bookingService'
import { paymentService } from '../../services/paymentService'
import { useAuth } from '../../context/AuthContext'
import { useToast } from '../../context/ToastContext'
import { Loading, EmptyState, StatusBadge } from '../../components/common'
import { currency } from '../../lib/constants'
import { fmtDate } from '../../lib/helpers'
import OwnerReceipts from './OwnerReceipts'

export default function OwnerBookings() {
  const { userId } = useAuth()
  const toast = useToast()
  const [tab, setTab] = useState('Bookings')
  const [bookings, setBookings] = useState([])
  const [payments, setPayments] = useState({})
  const [loading, setLoading] = useState(true)

  const load = async () => {
    try {
      const data = await bookingService.getOwnerBookings(userId)
      setBookings(data)
      const pmap = {}
      await Promise.all(data.map(async (b) => { pmap[b.id] = await paymentService.getByBooking(b.id).catch(() => null) }))
      setPayments(pmap)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { if (userId) load() }, [userId])

  const update = async (b, status) => {
    try {
      await bookingService.updateStatus(b.id, status, { userId: b.user_id, workspaceName: b.workspace_name })
      toast.success(`Booking ${status}`)
      load()
    } catch (err) { toast.error(err.message) }
  }

  const payLabel = (b) => {
    const p = payments[b.id]
    if (p?.receipt_status === 'awaiting_verification') return ['Receipt pending review', 'warning']
    if (p?.status === 'completed') return ['Paid', 'success']
    if (p?.receipt_status === 'rejected') return ['Receipt rejected', 'error']
    if (!p && b.status === 'confirmed') return ['Paid', 'success']
    if (p?.status === 'pending') return ['Awaiting transfer', 'neutral']
    return ['Not paid yet', 'neutral']
  }

  if (loading) return <Loading />

  return (
    <div className="container-app">
      <h3 className="fw-bold mb-3">Bookings</h3>
      <div className="pill-tabs mb-4">
        {['Bookings', 'Receipts'].map((t) => <button key={t} className={tab === t ? 'active' : ''} onClick={() => setTab(t)}>{t}</button>)}
      </div>

      {tab === 'Receipts' ? (
        <OwnerReceipts embedded />
      ) : bookings.length === 0 ? (
        <EmptyState icon="bi-calendar-x" title="No bookings yet" />
      ) : (
        <div className="row g-3">
          {bookings.map((b) => {
            const [label, variant] = payLabel(b)
            return (
              <div className="col-md-6" key={b.id}>
                <div className="card-clean p-3 h-100">
                  <div className="d-flex justify-content-between align-items-start mb-2">
                    <div>
                      <h6 className="fw-bold mb-1">{b.workspace_name}</h6>
                      <div className="small text-secondary"><i className="bi bi-calendar3 me-1"></i>{fmtDate(b.start_date)}{b.time_slot_label && ` · ${b.time_slot_label}`}</div>
                    </div>
                    <StatusBadge status={b.status} />
                  </div>
                  <div className="d-flex justify-content-between align-items-center mb-2">
                    <span className="fw-bold text-primary">{currency(b.total_price)}</span>
                    <span className={`badge-soft badge-${variant}-soft`}>{label}</span>
                  </div>
                  {b.status === 'pending' && (
                    <div className="d-flex gap-2">
                      <button className="btn btn-success btn-sm flex-fill" onClick={() => update(b, 'confirmed')}>Confirm</button>
                      <button className="btn btn-light btn-sm flex-fill text-danger" onClick={() => update(b, 'cancelled')}>Cancel</button>
                    </div>
                  )}
                </div>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
