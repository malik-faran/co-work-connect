import { useEffect, useState } from 'react'
import { workspaceService } from '../../services/workspaceService'
import { bookingService } from '../../services/bookingService'
import { useAuth } from '../../context/AuthContext'
import { Loading, StatusBadge } from '../../components/common'
import { currency } from '../../lib/constants'

export default function OwnerAnalytics() {
  const { userId } = useAuth()
  const [workspaces, setWorkspaces] = useState([])
  const [bookings, setBookings] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!userId) return
    Promise.all([workspaceService.getByOwner(userId), bookingService.getOwnerBookings(userId)])
      .then(([ws, bk]) => { setWorkspaces(ws); setBookings(bk) })
      .finally(() => setLoading(false))
  }, [userId])

  if (loading) return <Loading />

  const revenue = bookings.filter((b) => ['confirmed', 'completed'].includes(b.status)).reduce((s, b) => s + Number(b.total_price || 0), 0)
  const pending = bookings.filter((b) => b.status === 'pending').length
  const confirmed = bookings.filter((b) => b.status === 'confirmed').length

  const perWorkspace = workspaces.map((w) => {
    const wb = bookings.filter((b) => b.workspace_id === w.id)
    const rev = wb.filter((b) => ['confirmed', 'completed'].includes(b.status)).reduce((s, b) => s + Number(b.total_price || 0), 0)
    return { ...w, count: wb.length, rev }
  }).sort((a, b) => b.rev - a.rev)

  const stats = [
    { label: 'Total Revenue', value: currency(revenue), icon: 'bi-cash-stack', gradient: 'var(--success-gradient)' },
    { label: 'Total Bookings', value: bookings.length, icon: 'bi-calendar-check', gradient: 'var(--primary-gradient)' },
    { label: 'Pending', value: pending, icon: 'bi-hourglass-split', gradient: 'var(--warm-gradient)' },
    { label: 'Confirmed', value: confirmed, icon: 'bi-check-circle', gradient: 'var(--cool-gradient)' },
  ]

  return (
    <div className="container-app">
      <h3 className="fw-bold mb-3">Analytics</h3>
      <div className="row g-3 mb-4">
        {stats.map((s) => (
          <div className="col-6 col-lg-3" key={s.label}>
            <div className="stat-card" style={{ background: s.gradient }} data-aos="fade-up">
              <div className="d-flex justify-content-between align-items-start">
                <div>
                  <div className="fw-bold fs-4 text-white">{s.value}</div>
                  <div style={{ opacity: 0.9, fontSize: '0.82rem' }}>{s.label}</div>
                </div>
                <div className="stat-icon"><i className={`bi ${s.icon} text-white`}></i></div>
              </div>
            </div>
          </div>
        ))}
      </div>

      <div className="card-clean p-4">
        <h6 className="fw-bold mb-3">Workspace Performance</h6>
        {perWorkspace.length === 0 ? (
          <p className="text-secondary mb-0">No workspaces yet.</p>
        ) : (
          <div className="table-responsive">
            <table className="table align-middle mb-0">
              <thead><tr className="text-secondary small"><th>Workspace</th><th>City</th><th>Bookings</th><th>Revenue</th><th>Status</th></tr></thead>
              <tbody>
                {perWorkspace.map((w) => (
                  <tr key={w.id}>
                    <td className="fw-semibold">{w.name}</td>
                    <td className="text-secondary">{w.city}</td>
                    <td>{w.count}</td>
                    <td className="fw-semibold text-primary">{currency(w.rev)}</td>
                    <td><StatusBadge status={w.is_available ? 'active' : 'cancelled'} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  )
}
