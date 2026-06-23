import { useNavigate } from 'react-router-dom'

const CONTACTS = [
  { name: 'Police', number: '15', icon: 'bi-shield' },
  { name: 'Rescue / Ambulance', number: '1122', icon: 'bi-heart-pulse' },
  { name: 'Fire Brigade', number: '16', icon: 'bi-fire' },
  { name: 'Edhi Ambulance', number: '115', icon: 'bi-truck-front' },
]

export default function Sos() {
  const navigate = useNavigate()
  return (
    <div className="container-app" style={{ maxWidth: 560 }}>
      <button className="btn btn-light mb-3" onClick={() => navigate(-1)}><i className="bi bi-arrow-left me-1"></i>Back</button>
      <div className="card-clean p-4 text-center mb-3" style={{ background: 'var(--warm-gradient)', color: '#fff' }}>
        <i className="bi bi-shield-exclamation" style={{ fontSize: '3rem' }}></i>
        <h3 className="fw-bold text-white mt-2 mb-1">Emergency Help</h3>
        <p className="mb-0" style={{ opacity: 0.9 }}>Tap a contact below to call immediately.</p>
      </div>

      <div className="d-flex flex-column gap-2">
        {CONTACTS.map((c) => (
          <a key={c.number} href={`tel:${c.number}`} className="card-clean card-hover p-3 d-flex align-items-center gap-3 text-reset">
            <div className="stat-icon" style={{ background: 'var(--warm-gradient)', width: 48, height: 48 }}><i className={`bi ${c.icon} text-white fs-5`}></i></div>
            <div className="flex-fill">
              <div className="fw-bold">{c.name}</div>
              <div className="text-secondary small">Call {c.number}</div>
            </div>
            <i className="bi bi-telephone-fill text-success fs-5"></i>
          </a>
        ))}
      </div>

      <div className="alert alert-light mt-3 small text-secondary">
        <i className="bi bi-info-circle me-1"></i>In a real emergency, always call local services directly. Share your live location with someone you trust.
      </div>
    </div>
  )
}
