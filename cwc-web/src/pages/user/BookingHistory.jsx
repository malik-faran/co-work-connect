import { useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { bookingService } from '../../services/bookingService'
import { paymentService } from '../../services/paymentService'
import { reviewService } from '../../services/reviewService'
import { useAuth } from '../../context/AuthContext'
import { useToast } from '../../context/ToastContext'
import { Loading, EmptyState, StatusBadge, Modal } from '../../components/common'
import { currency } from '../../lib/constants'
import { fmtDate } from '../../lib/helpers'

const TABS = ['All', 'Active', 'Completed', 'Cancelled']

function ReviewModal({ booking, onClose, onDone }) {
  const { userId, profile } = useAuth()
  const toast = useToast()
  const [rating, setRating] = useState(5)
  const [comment, setComment] = useState('')
  const [saving, setSaving] = useState(false)

  const submit = async () => {
    if ((rating === 1 || rating === 5) && comment.trim().length < 10) {
      return toast.error('Please add a comment (min 10 characters) for this rating.')
    }
    setSaving(true)
    try {
      await reviewService.create({
        bookingId: booking.id,
        workspaceId: booking.workspace_id,
        userId,
        userName: profile?.name,
        userImage: profile?.profile_image_url,
        rating,
        comment: comment.trim() || null,
      })
      toast.success('Thanks for your review!')
      onDone()
    } catch (err) {
      toast.error(err.message || 'Could not submit review')
    } finally {
      setSaving(false)
    }
  }

  return (
    <Modal show onClose={onClose} title="Write a review" footer={
      <>
        <button className="btn btn-light" onClick={onClose}>Cancel</button>
        <button className="btn btn-primary" onClick={submit} disabled={saving}>
          {saving ? <span className="spinner-border spinner-border-sm me-2"></span> : null}Submit
        </button>
      </>
    }>
      <p className="text-secondary">{booking.workspace_name}</p>
      <div className="text-center mb-3">
        {[1, 2, 3, 4, 5].map((i) => (
          <button key={i} className="star-btn" onClick={() => setRating(i)}>
            <i className={`bi ${i <= rating ? 'bi-star-fill star' : 'bi-star star-empty'}`}></i>
          </button>
        ))}
      </div>
      <textarea className="form-control" rows={4} placeholder="Share your experience..." value={comment} onChange={(e) => setComment(e.target.value)} maxLength={500} />
      <div className="text-end small text-secondary mt-1">{comment.length}/500</div>
    </Modal>
  )
}

export default function BookingHistory() {
  const { userId } = useAuth()
  const navigate = useNavigate()
  const [bookings, setBookings] = useState([])
  const [payments, setPayments] = useState({})
  const [reviewed, setReviewed] = useState({})
  const [tab, setTab] = useState('All')
  const [loading, setLoading] = useState(true)
  const [reviewBooking, setReviewBooking] = useState(null)

  const load = async () => {
    try {
      const data = await bookingService.getUserBookings(userId)
      setBookings(data)
      const pmap = {}
      const rmap = {}
      await Promise.all(
        data.map(async (b) => {
          pmap[b.id] = await paymentService.getByBooking(b.id).catch(() => null)
          if (b.status === 'confirmed' || b.status === 'completed') {
            rmap[b.id] = await reviewService.hasReviewedBooking(b.id).catch(() => false)
          }
        })
      )
      setPayments(pmap)
      setReviewed(rmap)
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    if (userId) load()
  }, [userId])

  const filtered = bookings.filter((b) => {
    if (tab === 'Active') return ['pending', 'confirmed'].includes(b.status)
    if (tab === 'Completed') return b.status === 'completed'
    if (tab === 'Cancelled') return b.status === 'cancelled'
    return true
  })

  if (loading) return <Loading message="Loading your bookings..." />

  return (
    <div className="container-app">
      <h3 className="fw-bold mb-3">My Bookings</h3>
      <div className="pill-tabs mb-4">
        {TABS.map((t) => (
          <button key={t} className={tab === t ? 'active' : ''} onClick={() => setTab(t)}>{t}</button>
        ))}
      </div>

      {filtered.length === 0 ? (
        <EmptyState icon="bi-calendar-x" title="No bookings here" subtitle="Browse spaces and make your first booking." action={<Link to="/home" className="btn btn-primary">Explore Workspaces</Link>} />
      ) : (
        <div className="row g-3">
          {filtered.map((b) => {
            const pay = payments[b.id]
            const canPay = b.status === 'pending' && (!pay || pay.status !== 'completed')
            const canTicket = (b.status === 'confirmed' || b.status === 'completed') && (!pay || pay.status === 'completed')
            const canReview = (b.status === 'confirmed' || b.status === 'completed') && !reviewed[b.id]
            return (
              <div className="col-md-6" key={b.id}>
                <div className="card-clean p-3 h-100">
                  <div className="d-flex justify-content-between align-items-start mb-2">
                    <div>
                      <h6 className="fw-bold mb-1">{b.workspace_name}</h6>
                      <div className="text-secondary small">
                        <i className="bi bi-calendar3 me-1"></i>{fmtDate(b.start_date)}
                        {b.is_hourly_booking && b.time_slot_label && <span> · {b.time_slot_label}</span>}
                      </div>
                    </div>
                    <StatusBadge status={b.status} />
                  </div>
                  <div className="d-flex gap-3 small text-secondary mb-2">
                    {b.category_type && <span><i className="bi bi-tag me-1"></i>{b.category_type}</span>}
                    <span><i className="bi bi-people me-1"></i>{b.seat_count} seat{b.seat_count > 1 ? 's' : ''}</span>
                  </div>
                  <div className="d-flex justify-content-between align-items-center">
                    <span className="fw-bold text-primary">{currency(b.total_price)}</span>
                    <div className="d-flex gap-2">
                      {canPay && <button className="btn btn-primary btn-sm" onClick={() => navigate(`/payment/${b.id}`)}><i className="bi bi-credit-card me-1"></i>Pay Now</button>}
                      {canTicket && <button className="btn btn-light btn-sm" onClick={() => navigate(`/booking/${b.id}/confirmation`)}><i className="bi bi-ticket-perforated me-1"></i>Ticket</button>}
                      {canReview && <button className="btn btn-outline-primary btn-sm" onClick={() => setReviewBooking(b)}><i className="bi bi-star me-1"></i>Review</button>}
                    </div>
                  </div>
                  {pay?.receipt_status === 'awaiting_verification' && <div className="small text-warning mt-2"><i className="bi bi-hourglass-split me-1"></i>Receipt under review</div>}
                  {pay?.receipt_status === 'rejected' && <div className="small text-danger mt-2"><i className="bi bi-x-circle me-1"></i>Receipt rejected — please re-submit</div>}
                </div>
              </div>
            )
          })}
        </div>
      )}

      {reviewBooking && (
        <ReviewModal booking={reviewBooking} onClose={() => setReviewBooking(null)} onDone={() => { setReviewBooking(null); load() }} />
      )}
    </div>
  )
}
