import { Link } from 'react-router-dom'
import { APP_TAGLINE } from '../../lib/constants'

export default function AuthShell({ title, subtitle, children, footer }) {
  return (
    <div className="min-vh-100 d-flex">
      {/* Left brand panel */}
      <div
        className="d-none d-lg-flex flex-column justify-content-between p-5 hero"
        style={{ width: '42%', color: '#fff' }}
      >
        <Link to="/welcome" className="d-flex align-items-center gap-2 text-white position-relative" style={{ zIndex: 2 }}>
          <span className="brand-logo" style={{ background: 'rgba(255,255,255,0.2)' }}>C</span>
          <span className="fw-bold fs-4 text-white">CWL</span>
        </Link>
        <div className="position-relative" style={{ zIndex: 2 }}>
          <h2 className="fw-bold text-white mb-3" style={{ fontSize: '2.4rem', letterSpacing: '-1px' }}>
            {APP_TAGLINE}
          </h2>
          <p style={{ color: 'rgba(255,255,255,0.85)' }}>
            Your all-in-one platform for coworking spaces and project collaboration.
          </p>
          <div className="d-flex gap-4 mt-4">
            <div><div className="fw-bold fs-4 text-white">Spaces</div><div className="small" style={{ color: 'rgba(255,255,255,0.8)' }}>Book by hour/day/month</div></div>
            <div><div className="fw-bold fs-4 text-white">Teams</div><div className="small" style={{ color: 'rgba(255,255,255,0.8)' }}>Recruit & collaborate</div></div>
          </div>
        </div>
        <div className="small position-relative" style={{ zIndex: 2, color: 'rgba(255,255,255,0.7)' }}>
          © {new Date().getFullYear()} CWL
        </div>
      </div>

      {/* Right form panel */}
      <div className="flex-fill d-flex align-items-center justify-content-center p-4 bg-app">
        <div className="w-100 animate__animated animate__fadeIn" style={{ maxWidth: 420 }}>
          <Link to="/welcome" className="d-lg-none d-flex align-items-center gap-2 mb-4 justify-content-center">
            <span className="brand-logo">C</span>
            <span className="fw-bold fs-4" style={{ color: 'var(--text-primary)' }}>CWL</span>
          </Link>
          <h3 className="fw-bold mb-1">{title}</h3>
          {subtitle && <p className="text-secondary mb-4">{subtitle}</p>}
          {children}
          {footer && <div className="text-center mt-4">{footer}</div>}
        </div>
      </div>
    </div>
  )
}
