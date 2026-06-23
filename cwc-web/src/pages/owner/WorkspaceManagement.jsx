import { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { workspaceService } from '../../services/workspaceService'
import { useToast } from '../../context/ToastContext'
import { Loading } from '../../components/common'
import { currency, WORKSPACE_TYPE_LABELS, AMENITY_ICONS } from '../../lib/constants'
import { getCategories } from '../../lib/helpers'

export default function WorkspaceManagement() {
  const { id } = useParams()
  const navigate = useNavigate()
  const toast = useToast()
  const [ws, setWs] = useState(null)
  const [loading, setLoading] = useState(true)

  const load = () => workspaceService.getById(id).then(setWs).finally(() => setLoading(false))
  useEffect(() => { load() }, [id])

  if (loading) return <Loading />
  if (!ws) return <div className="container-app"><p>Workspace not found.</p></div>

  const categories = getCategories(ws)

  const toggleAvail = async () => {
    try {
      await workspaceService.setAvailability(id, !ws.is_available)
      setWs({ ...ws, is_available: !ws.is_available })
      toast.success('Availability updated')
    } catch (err) { toast.error(err.message) }
  }

  const remove = async () => {
    if (!confirm('Delete this workspace permanently?')) return
    try {
      await workspaceService.remove(id)
      toast.success('Workspace deleted')
      navigate('/owner')
    } catch (err) { toast.error(err.message) }
  }

  return (
    <div className="container-app" style={{ maxWidth: 820 }}>
      <button className="btn btn-light mb-3" onClick={() => navigate('/owner')}><i className="bi bi-arrow-left me-1"></i>Dashboard</button>

      <div className="card-clean overflow-hidden mb-3">
        {ws.image_urls?.[0] ? (
          <img src={ws.image_urls[0]} alt={ws.name} style={{ height: 220, width: '100%', objectFit: 'cover' }} />
        ) : (
          <div className="ws-img-placeholder" style={{ height: 220 }}><i className="bi bi-building fs-1" style={{ opacity: 0.7 }}></i></div>
        )}
        <div className="p-4">
          <div className="d-flex justify-content-between align-items-start">
            <div>
              <h3 className="fw-bold mb-1">{ws.name}</h3>
              <div className="text-secondary"><i className="bi bi-geo-alt me-1"></i>{[ws.address, ws.city].filter(Boolean).join(', ')}</div>
            </div>
            <span className={`badge-soft ${ws.is_available ? 'badge-success-soft' : 'badge-error-soft'}`}>{ws.is_available ? 'Available' : 'Unavailable'}</span>
          </div>
        </div>
      </div>

      <div className="card-clean p-4 mb-3">
        <h6 className="fw-bold mb-2">Description</h6>
        <p className="text-secondary">{ws.description || 'No description.'}</p>
      </div>

      <div className="card-clean p-4 mb-3">
        <h6 className="fw-bold mb-3">Categories & pricing</h6>
        {categories.map((c) => (
          <div key={c.type} className="d-flex justify-content-between border-bottom py-2">
            <span className="fw-semibold">{WORKSPACE_TYPE_LABELS[c.type] || c.type}</span>
            <span className="text-secondary">{c.capacity} seats · {currency(c.pricePerHour)}/hr · {currency(c.pricePerDay)}/day</span>
          </div>
        ))}
      </div>

      {(ws.amenities || []).length > 0 && (
        <div className="card-clean p-4 mb-3">
          <h6 className="fw-bold mb-3">Amenities</h6>
          <div className="d-flex flex-wrap gap-2">
            {ws.amenities.map((a) => <span key={a} className="chip chip-static"><i className={`bi ${AMENITY_ICONS[a] || 'bi-check'}`}></i>{a}</span>)}
          </div>
        </div>
      )}

      <div className="card-clean p-3 mb-3 d-flex justify-content-between align-items-center">
        <span className="fw-semibold">Available for booking</span>
        <div className="form-check form-switch mb-0">
          <input className="form-check-input" type="checkbox" checked={ws.is_available} onChange={toggleAvail} style={{ width: 44, height: 24 }} />
        </div>
      </div>

      <div className="d-flex gap-2">
        <button className="btn btn-primary flex-fill" onClick={() => navigate(`/owner/workspace/${id}/edit`)}><i className="bi bi-pencil me-1"></i>Edit Workspace</button>
        <button className="btn btn-light text-danger" onClick={remove}><i className="bi bi-trash me-1"></i>Delete</button>
      </div>
    </div>
  )
}
