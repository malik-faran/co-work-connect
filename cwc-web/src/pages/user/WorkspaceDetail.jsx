import { useEffect, useMemo, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { workspaceService } from '../../services/workspaceService'
import { reviewService } from '../../services/reviewService'
import { bookingService } from '../../services/bookingService'
import { chatService } from '../../services/chatService'
import { useAuth } from '../../context/AuthContext'
import { useToast } from '../../context/ToastContext'
import { Loading, Stars, Avatar, EmptyState } from '../../components/common'
import { currency, AMENITY_ICONS, WORKSPACE_TYPE_LABELS } from '../../lib/constants'
import { getCategories, getTimeSlots, timeAgo, dateKey } from '../../lib/helpers'

export default function WorkspaceDetail() {
  const { id } = useParams()
  const navigate = useNavigate()
  const { userId, profile } = useAuth()
  const toast = useToast()

  const [ws, setWs] = useState(null)
  const [reviews, setReviews] = useState([])
  const [loading, setLoading] = useState(true)
  const [imgIdx, setImgIdx] = useState(0)

  // booking state
  const [category, setCategory] = useState(null)
  const [mode, setMode] = useState('hourly')
  const [date, setDate] = useState(new Date())
  const [selectedSlots, setSelectedSlots] = useState([])
  const [seatCount, setSeatCount] = useState(1)
  const [monthCount, setMonthCount] = useState(1)
  const [bookedSeats, setBookedSeats] = useState({})
  const [booking, setBooking] = useState(false)

  const categories = useMemo(() => (ws ? getCategories(ws) : []), [ws])
  const slots = useMemo(() => (ws ? getTimeSlots(ws) : []), [ws])

  useEffect(() => {
    Promise.all([workspaceService.getById(id), reviewService.getForWorkspace(id)])
      .then(([w, r]) => {
        setWs(w)
        setReviews(r)
      })
      .catch(console.error)
      .finally(() => setLoading(false))
  }, [id])

  useEffect(() => {
    if (categories.length && !category) setCategory(categories[0])
  }, [categories, category])

  useEffect(() => {
    if (!ws) return
    bookingService.getBookedSeats(ws.id, dateKey(date)).then(setBookedSeats).catch(() => {})
    setSelectedSlots([])
  }, [ws, date])

  if (loading) return <Loading message="Loading workspace..." />
  if (!ws) return <div className="container-app"><EmptyState icon="bi-building-x" title="Workspace not found" /></div>

  const images = ws.image_urls || []
  const next7 = Array.from({ length: 7 }, (_, i) => {
    const d = new Date()
    d.setDate(d.getDate() + i)
    return d
  })

  const slotAvailable = (slot) => {
    const key = `${slot.id}|${category?.type || ''}`
    const booked = bookedSeats[key] || 0
    return Math.max(0, (category?.capacity || 0) - booked)
  }

  const toggleSlot = (slot) => {
    if (slotAvailable(slot) <= 0) return
    setSelectedSlots((prev) =>
      prev.find((s) => s.id === slot.id) ? prev.filter((s) => s.id !== slot.id) : [...prev, slot]
    )
  }

  const maxSeats = selectedSlots.length
    ? Math.min(...selectedSlots.map((s) => slotAvailable(s)))
    : category?.capacity || 1

  const total = useMemo(() => {
    if (!category) return 0
    if (mode === 'hourly') {
      return selectedSlots.reduce(
        (sum, s) => sum + category.pricePerHour * (s.endHour - s.startHour) * seatCount,
        0
      )
    }
    if (mode === 'monthly') return category.pricePerDay * 30 * monthCount
    return category.pricePerDay
  }, [category, mode, selectedSlots, seatCount, monthCount])

  const canBook =
    category &&
    (mode === 'daily' || mode === 'monthly' || (mode === 'hourly' && selectedSlots.length > 0))

  const handleBook = async () => {
    if (!canBook) return
    setBooking(true)
    try {
      const rows = await bookingService.createBookings({
        workspace: ws,
        userId,
        mode,
        date,
        category,
        slots: selectedSlots,
        seatCount,
        monthCount,
      })
      toast.success('Booking created! Complete your payment.')
      navigate(`/payment/${rows[0].id}`)
    } catch (err) {
      toast.error(err.message || 'Booking failed')
    } finally {
      setBooking(false)
    }
  }

  const contactOwner = async () => {
    try {
      const room = await chatService.getOrCreateDirectRoom({
        user1Id: userId,
        user2Id: ws.owner_id,
        workspaceId: ws.id,
      })
      navigate(`/chats/${room.id}`)
    } catch (err) {
      toast.error('Could not start chat')
    }
  }

  return (
    <div className="container-app">
      <button className="btn btn-light mb-3" onClick={() => navigate(-1)}>
        <i className="bi bi-arrow-left me-1"></i>Back
      </button>

      <div className="row g-4">
        {/* Left: details */}
        <div className="col-lg-7">
          {/* Image carousel */}
          <div className="card-clean overflow-hidden mb-3">
            <div className="position-relative" style={{ background: '#eef2ff' }}>
              {images.length ? (
                <img src={images[imgIdx]} alt={ws.name} style={{ width: '100%', height: 360, objectFit: 'cover' }} />
              ) : (
                <div className="ws-img-placeholder" style={{ height: 360 }}>
                  <i className="bi bi-building" style={{ fontSize: '4rem', opacity: 0.7 }}></i>
                </div>
              )}
              {images.length > 1 && (
                <>
                  <button className="btn btn-light position-absolute top-50 start-0 translate-middle-y ms-2 rounded-circle" onClick={() => setImgIdx((imgIdx - 1 + images.length) % images.length)}>
                    <i className="bi bi-chevron-left"></i>
                  </button>
                  <button className="btn btn-light position-absolute top-50 end-0 translate-middle-y me-2 rounded-circle" onClick={() => setImgIdx((imgIdx + 1) % images.length)}>
                    <i className="bi bi-chevron-right"></i>
                  </button>
                  <div className="position-absolute bottom-0 start-50 translate-middle-x mb-2 d-flex gap-1">
                    {images.map((_, i) => (
                      <span key={i} style={{ width: 8, height: 8, borderRadius: 8, background: i === imgIdx ? '#fff' : 'rgba(255,255,255,0.5)' }} />
                    ))}
                  </div>
                </>
              )}
            </div>
          </div>

          {/* Title + meta */}
          <div className="card-clean p-4 mb-3">
            <div className="d-flex justify-content-between align-items-start">
              <div>
                <h3 className="fw-bold mb-1">{ws.name}</h3>
                <div className="text-secondary"><i className="bi bi-geo-alt me-1"></i>{[ws.address, ws.city, ws.state, ws.country].filter(Boolean).join(', ')}</div>
              </div>
              <span className={`badge-soft ${ws.is_available ? 'badge-success-soft' : 'badge-error-soft'}`}>
                {ws.is_available ? 'Available' : 'Full'}
              </span>
            </div>
            <div className="d-flex gap-3 flex-wrap mt-3">
              <span className="chip chip-static"><i className="bi bi-clock"></i>{ws.opening_time} - {ws.closing_time}</span>
              <span className="chip chip-static"><Stars value={ws.rating || 0} size="0.8rem" /> {Number(ws.rating || 0).toFixed(1)} ({ws.total_reviews || 0})</span>
              <span className="chip chip-static"><i className="bi bi-people"></i>{category?.capacity || ws.capacity} seats</span>
            </div>
            <hr className="divider my-3" />
            <h6 className="fw-bold">About this space</h6>
            <p className="text-secondary mb-0" style={{ whiteSpace: 'pre-wrap' }}>{ws.description || 'No description provided.'}</p>
          </div>

          {/* Amenities */}
          {(ws.amenities || []).length > 0 && (
            <div className="card-clean p-4 mb-3">
              <h6 className="fw-bold mb-3">Amenities</h6>
              <div className="row g-2">
                {ws.amenities.map((a) => (
                  <div className="col-6 col-md-4" key={a}>
                    <div className="d-flex align-items-center gap-2">
                      <i className={`bi ${AMENITY_ICONS[a] || 'bi-check-circle'} text-primary`}></i>
                      <span className="small">{a}</span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Reviews */}
          <div className="card-clean p-4">
            <div className="d-flex justify-content-between align-items-center mb-3">
              <h6 className="fw-bold mb-0">Reviews ({ws.total_reviews || 0})</h6>
              <span><Stars value={ws.rating || 0} /> <span className="fw-semibold ms-1">{Number(ws.rating || 0).toFixed(1)}</span></span>
            </div>
            {reviews.length === 0 ? (
              <p className="text-secondary small mb-0">No reviews yet. Be the first after your booking!</p>
            ) : (
              <div className="d-flex flex-column gap-3">
                {reviews.slice(0, 5).map((r) => (
                  <div key={r.id} className="d-flex gap-3">
                    <Avatar src={r.user_profile_image} name={r.user_name} size={42} />
                    <div className="flex-fill">
                      <div className="d-flex justify-content-between">
                        <span className="fw-semibold">{r.user_name}</span>
                        <span className="text-secondary small">{timeAgo(r.created_at)}</span>
                      </div>
                      <Stars value={r.rating} size="0.8rem" />
                      {r.comment && <p className="mb-0 small text-secondary mt-1">{r.comment}</p>}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Right: booking */}
        <div className="col-lg-5">
          <div className="card-clean p-4 sticky-top" style={{ top: 88 }}>
            <h5 className="fw-bold mb-3">Book this space</h5>

            {/* Category */}
            <label className="form-label">Workspace type</label>
            <div className="d-flex gap-2 flex-wrap mb-3">
              {categories.map((c) => (
                <button key={c.type} className={`chip ${category?.type === c.type ? 'active' : ''}`} onClick={() => setCategory(c)}>
                  {WORKSPACE_TYPE_LABELS[c.type] || c.type} · {c.capacity} seats
                </button>
              ))}
            </div>

            {/* Date */}
            <label className="form-label">Select date</label>
            <div className="d-flex gap-2 overflow-auto pb-2 mb-3">
              {next7.map((d) => {
                const active = dateKey(d) === dateKey(date)
                return (
                  <button key={d.toISOString()} className={`btn ${active ? 'btn-primary' : 'btn-light'} flex-shrink-0`} style={{ minWidth: 64 }} onClick={() => setDate(d)}>
                    <div className="small">{d.toLocaleDateString('en', { weekday: 'short' })}</div>
                    <div className="fw-bold">{d.getDate()}</div>
                  </button>
                )
              })}
            </div>

            {/* Mode */}
            <label className="form-label">Booking plan</label>
            <div className="row g-2 mb-3">
              {[
                { key: 'hourly', label: 'Hourly', price: category ? `${currency(category.pricePerHour)}/hr` : '' },
                { key: 'daily', label: 'Full Day', price: category ? `${currency(category.pricePerDay)}/day` : '' },
                { key: 'monthly', label: 'Monthly', price: category ? `${currency(category.pricePerDay * 30)}/mo` : '' },
              ].map((m) => (
                <div className="col-4" key={m.key}>
                  <button className={`btn w-100 h-100 ${mode === m.key ? 'btn-primary' : 'btn-light'}`} onClick={() => setMode(m.key)} style={{ flexDirection: 'column', display: 'flex' }}>
                    <span className="fw-semibold">{m.label}</span>
                    <span className="small" style={{ opacity: 0.8 }}>{m.price}</span>
                  </button>
                </div>
              ))}
            </div>

            {/* Slots (hourly) */}
            {mode === 'hourly' && (
              <>
                <label className="form-label">Available slots</label>
                <div className="d-flex gap-2 flex-wrap mb-3">
                  {slots.map((s) => {
                    const avail = slotAvailable(s)
                    const sel = !!selectedSlots.find((x) => x.id === s.id)
                    return (
                      <button key={s.id} disabled={avail <= 0} className={`chip ${sel ? 'active' : ''}`} onClick={() => toggleSlot(s)} style={avail <= 0 ? { opacity: 0.4 } : {}}>
                        {sel && <i className="bi bi-check"></i>}
                        {s.label}
                        <span className="ms-1" style={{ opacity: 0.7 }}>({avail})</span>
                      </button>
                    )
                  })}
                </div>
                {selectedSlots.length > 0 && (
                  <div className="mb-3">
                    <label className="form-label">Seats</label>
                    <select className="form-select" value={seatCount} onChange={(e) => setSeatCount(Number(e.target.value))}>
                      {Array.from({ length: Math.max(1, maxSeats) }, (_, i) => i + 1).map((n) => (
                        <option key={n} value={n}>{n} seat{n > 1 ? 's' : ''}</option>
                      ))}
                    </select>
                  </div>
                )}
              </>
            )}

            {/* Months (monthly) */}
            {mode === 'monthly' && (
              <div className="mb-3">
                <label className="form-label">Number of months</label>
                <div className="d-flex align-items-center gap-3">
                  <button className="btn btn-light" onClick={() => setMonthCount(Math.max(1, monthCount - 1))}><i className="bi bi-dash"></i></button>
                  <span className="fw-bold fs-5">{monthCount}</span>
                  <button className="btn btn-light" onClick={() => setMonthCount(Math.min(12, monthCount + 1))}><i className="bi bi-plus"></i></button>
                </div>
              </div>
            )}

            <hr className="divider my-3" />
            <div className="d-flex justify-content-between align-items-center mb-3">
              <span className="text-secondary">Total</span>
              <span className="fw-bold fs-4 text-primary">{currency(total)}</span>
            </div>

            <div className="d-grid gap-2">
              <button className="btn btn-primary btn-lg" disabled={!canBook || booking || !ws.is_available} onClick={handleBook}>
                {booking ? <span className="spinner-border spinner-border-sm me-2"></span> : <i className="bi bi-calendar-check me-2"></i>}
                {mode === 'hourly' ? `Book ${selectedSlots.length || ''} Slot${selectedSlots.length !== 1 ? 's' : ''}` : mode === 'monthly' ? `Book ${monthCount} Month${monthCount > 1 ? 's' : ''}` : 'Book Full Day'}
              </button>
              <button className="btn btn-outline-primary" onClick={contactOwner}>
                <i className="bi bi-chat-dots me-2"></i>Contact Owner
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
