import { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { supabase } from '../../lib/supabase'
import { Loading, StatusBadge } from '../../components/common'
import { currency } from '../../lib/constants'
import { fmtDate, dateKey } from '../../lib/helpers'

export default function BookingConfirmation() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [booking, setBooking] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    supabase
      .from('bookings')
      .select('*')
      .eq('id', id)
      .maybeSingle()
      .then(({ data }) => setBooking(data))
      .finally(() => setLoading(false))
  }, [id])

  if (loading) return <Loading />
  if (!booking) return <div className="container-app"><p>Booking not found.</p></div>

  const qrData = encodeURIComponent(
    JSON.stringify({
      bookingId: booking.id,
      workspace: booking.workspace_name,
      date: dateKey(booking.start_date),
      amount: booking.total_price,
    })
  )
  const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${qrData}`

  return (
    <div className="container-app" style={{ maxWidth: 520 }}>
      <div className="text-center mb-4 animate__animated animate__fadeInDown">
        <div className="empty-icon mx-auto mb-3" style={{ background: '#dcfce7', color: '#16a34a' }}>
          <i className="bi bi-check-lg fs-1"></i>
        </div>
        <h3 className="fw-bold">Booking Confirmed!</h3>
        <p className="text-secondary">Show this ticket at the workspace.</p>
      </div>

      <div className="card-clean overflow-hidden">
        <div className="p-4 text-white" style={{ background: 'var(--hero-gradient)' }}>
          <div className="d-flex justify-content-between align-items-center">
            <h5 className="fw-bold text-white mb-0">{booking.workspace_name}</h5>
            <span className="badge-soft" style={{ background: 'rgba(255,255,255,0.25)', color: '#fff' }}>
              {booking.is_hourly_booking ? 'Hourly' : 'Full Day'}
            </span>
          </div>
        </div>
        <div className="p-4">
          <div className="text-center mb-3">
            <img src={qrUrl} alt="QR" style={{ borderRadius: 12 }} />
          </div>
          {[
            ['Date', fmtDate(booking.start_date)],
            ['Time', booking.time_slot_label || (booking.is_hourly_booking ? '-' : 'Full Day')],
            ['Category', booking.category_type || '-'],
            ['Seats', booking.seat_count],
            ['Booking ID', booking.id.slice(0, 8).toUpperCase()],
          ].map(([k, v]) => (
            <div className="d-flex justify-content-between py-2 border-bottom" key={k}>
              <span className="text-secondary">{k}</span>
              <span className="fw-semibold">{v}</span>
            </div>
          ))}
          <div className="d-flex justify-content-between py-2">
            <span className="text-secondary">Total Paid</span>
            <span className="fw-bold text-primary fs-5">{currency(booking.total_price)}</span>
          </div>
          <div className="text-center mt-2"><StatusBadge status={booking.status} /></div>
        </div>
      </div>

      <div className="d-grid gap-2 mt-3">
        <button className="btn btn-primary" onClick={() => navigate('/bookings')}>View All Bookings</button>
        <button className="btn btn-light" onClick={() => navigate('/home')}>Back to Explore</button>
      </div>
    </div>
  )
}
