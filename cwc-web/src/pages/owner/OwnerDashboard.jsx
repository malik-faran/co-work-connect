import { useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { workspaceService } from '../../services/workspaceService'
import { bookingService } from '../../services/bookingService'
import { useAuth } from '../../context/AuthContext'
import { Loading, EmptyState } from '../../components/common'
import { currency } from '../../lib/constants'

export default function OwnerDashboard() {
  const { userId, profile } = useAuth()
  const navigate = useNavigate()
  const [workspaces, setWorkspaces] = useState([])
  const [bookings, setBookings] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!userId) return
    Promise.all([workspaceService.getByOwner(userId), bookingService.getOwnerBookings(userId)])
      .then(([ws, bk]) => { setWorkspaces(ws); setBookings(bk) })
      .finally(() => setLoading(false))
  }, [userId])

  if (loading) return <Loading message="Loading dashboard..." />

  const revenue = bookings.filter((b) => ['confirmed', 'completed'].includes(b.status)).reduce((s, b) => s + Number(b.total_price || 0), 0)
  const available = workspaces.filter((w) => w.is_available).length

  const stats = [
    { label: 'Workspaces', value: workspaces.length, icon: 'bi-building', gradient: 'var(--primary-gradient)' },
    { label: 'Available', value: available, icon: 'bi-check-circle', gradient: 'var(--success-gradient)' },
    { label: 'Bookings', value: bookings.length, icon: 'bi-calendar-check', gradient: 'var(--cool-gradient)' },
    { label: 'Revenue', value: currency(revenue), icon: 'bi-cash-stack', gradient: 'var(--warm-gradient)' },
  ]

  return (
    <div className="container-app">
      <div className="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-4">
        <div>
          <p className="text-secondary mb-0">Welcome back, {profile?.name?.split(' ')[0]}</p>
          <h3 className="fw-bold mb-0">Owner Dashboard</h3>
        </div>
        <div className="d-flex gap-2">
          <Link to="/owner/receipts" className="btn btn-light"><i className="bi bi-receipt-cutoff me-1"></i>Receipts</Link>
          <Link to="/owner/workspace/new" className="btn btn-primary"><i className="bi bi-plus-lg me-1"></i>Add Workspace</Link>
        </div>
      </div>

      <div className="row g-3 mb-4">
        {stats.map((s) => (
          <div className="col-6 col-lg-3" key={s.label}>
            <div className="stat-card" style={{ background: s.gradient }} data-aos="fade-up">
              <div className="d-flex justify-content-between align-items-start">
                <div>
                  <div className="fw-bold fs-3 text-white">{s.value}</div>
                  <div style={{ opacity: 0.9, fontSize: '0.85rem' }}>{s.label}</div>
                </div>
                <div className="stat-icon"><i className={`bi ${s.icon} text-white`}></i></div>
              </div>
            </div>
          </div>
        ))}
      </div>

      <div className="d-flex justify-content-between align-items-center mb-3">
        <h5 className="fw-bold mb-0">My Workspaces</h5>
      </div>

      {workspaces.length === 0 ? (
        <EmptyState icon="bi-building-add" title="No workspaces yet" subtitle="Add your first coworking space to start receiving bookings." action={<Link to="/owner/workspace/new" className="btn btn-primary">Add Workspace</Link>} />
      ) : (
        <div className="row g-3">
          {workspaces.map((ws) => (
            <div className="col-sm-6 col-lg-4" key={ws.id}>
              <div className="card-clean overflow-hidden h-100">
                {ws.image_urls?.[0] ? (
                  <img src={ws.image_urls[0]} alt={ws.name} className="ws-img" style={{ height: 150 }} />
                ) : (
                  <div className="ws-img-placeholder" style={{ height: 150 }}><i className="bi bi-building fs-1" style={{ opacity: 0.7 }}></i></div>
                )}
                <div className="p-3">
                  <div className="d-flex justify-content-between align-items-start">
                    <h6 className="fw-bold mb-1 line-clamp-1">{ws.name}</h6>
                    <span className={`badge-soft ${ws.is_available ? 'badge-success-soft' : 'badge-error-soft'}`}>{ws.is_available ? 'Live' : 'Off'}</span>
                  </div>
                  <div className="small text-secondary mb-2 line-clamp-1"><i className="bi bi-geo-alt me-1"></i>{ws.city}</div>
                  <div className="d-flex justify-content-between align-items-center">
                    <span className="fw-bold text-primary">{currency(ws.price_per_day)}<span className="fw-normal text-secondary small">/day</span></span>
                    <button className="btn btn-soft btn-sm" onClick={() => navigate(`/owner/workspace/${ws.id}`)}>Manage</button>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
