import { Link } from 'react-router-dom'
import { currency } from '../lib/constants'
import { Stars } from './common'
import { AMENITY_ICONS } from '../lib/constants'

export default function WorkspaceCard({ ws }) {
  const img = ws.image_urls?.[0]
  return (
    <Link to={`/workspace/${ws.id}`} className="text-reset">
      <div className="card-clean card-hover h-100 overflow-hidden" data-aos="fade-up">
        <div className="position-relative">
          {img ? (
            <img src={img} alt={ws.name} className="ws-img" />
          ) : (
            <div className="ws-img-placeholder">
              <i className="bi bi-building" style={{ fontSize: '3rem', opacity: 0.7 }}></i>
            </div>
          )}
          <span
            className={`badge-soft position-absolute ${ws.is_available ? 'badge-success-soft' : 'badge-error-soft'}`}
            style={{ top: 12, left: 12 }}
          >
            <i className={`bi ${ws.is_available ? 'bi-check-circle' : 'bi-x-circle'} me-1`}></i>
            {ws.is_available ? 'Available' : 'Full'}
          </span>
          <span
            className="position-absolute fw-bold px-3 py-1"
            style={{
              bottom: 12,
              right: 12,
              background: 'rgba(255,255,255,0.92)',
              borderRadius: 999,
              fontSize: '0.85rem',
              color: 'var(--primary-dark)',
            }}
          >
            {currency(ws.price_per_day)}<span className="text-secondary fw-normal">/day</span>
          </span>
        </div>
        <div className="p-3">
          <div className="d-flex justify-content-between align-items-start gap-2">
            <h6 className="fw-bold mb-1 line-clamp-1">{ws.name}</h6>
          </div>
          <div className="d-flex align-items-center gap-2 mb-2">
            <Stars value={ws.rating || 0} size="0.8rem" />
            <span className="text-secondary small">
              {Number(ws.rating || 0).toFixed(1)} ({ws.total_reviews || 0})
            </span>
          </div>
          <div className="text-secondary small line-clamp-1 mb-2">
            <i className="bi bi-geo-alt me-1"></i>
            {[ws.address, ws.city].filter(Boolean).join(', ')}
          </div>
          <div className="d-flex flex-wrap gap-1">
            {(ws.amenities || []).slice(0, 3).map((a) => (
              <span key={a} className="chip chip-static" style={{ fontSize: '0.72rem', padding: '0.2rem 0.55rem' }}>
                <i className={`bi ${AMENITY_ICONS[a] || 'bi-dot'}`}></i>
                {a}
              </span>
            ))}
            {(ws.amenities || []).length > 3 && (
              <span className="chip chip-static" style={{ fontSize: '0.72rem', padding: '0.2rem 0.55rem' }}>
                +{ws.amenities.length - 3}
              </span>
            )}
          </div>
        </div>
      </div>
    </Link>
  )
}
